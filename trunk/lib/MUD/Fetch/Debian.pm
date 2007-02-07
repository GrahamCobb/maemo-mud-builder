#
# MUD::Fetch::Debian                        (c) Andrew Flegg 2007
# ~~~~~~~~~~~~~~~~~~                        Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Fetch::Debian;

use strict;
use vars qw(@ISA $VERSION);
use MUD::Fetch::Base;
use Carp;
use Data::Dumper;

@ISA     = qw(MUD::Fetch::Base);
$VERSION = '0.10';

our $repo = 'http://ftp.debian.org/ etch main';

sub fetch {
    my $self = shift;

    $self->addSource();

    my $name     = $self->{package}->{name};
    my $upstream = $self->{package}->{data}->{fetch}->{name} || $name;
    my $buildDir = $self->{workdir};
    mkdir $buildDir unless -d $buildDir;
    chdir $buildDir;

    my $out = $self->apt('source', $upstream);
    opendir(SRCDIR, '.');
    my @d = grep { -d $_ and /^\w+/ } readdir(SRCDIR);
    closedir(SRCDIR);
    
    croak "Couldn't find extract directory!\n" unless @d;
    $self->{package}->{build} = $buildDir.'/'.$d[0];

    chdir $self->{package}->{build};
    my %list = ();
    my $deps = $self->{package}->{data}->{fetch}->{depends} ||
                  `dpkg-checkbuilddeps 2>&1`;
    $deps =~ s/.*Unmet build dependencies: //is;
    my %list = map { $_ => 0 }
               grep { /^[\w\._\-]+$/ }
               split /[\s\r\n]+/, $deps;

    if (keys(%list)) {
	warn "Need extra deps: ".join(", ", keys(%list))."\n";
        foreach my $dep (keys %list) {
            my $build;
            
	    # -- Build from one of MUD, existing binaries or upstream source...
	    #
	    if (-f $self->{config}->directory('PACKAGES_DIR') . "/$dep.xml") {
                $build = new MUD::Build( package => $dep );

            } else {
                system('fakeroot', 'apt-get', '-y', 'install', $dep);
    	        my $dpkg = `dpkg -s $dep 2>/dev/null`;
                print $dpkg;
                if ($dpkg !~ /Status: install ok installed/) {
		    print "+++ Status not installed.\n";
                    my $newPkg = new MUD::Package( (%{ $self->{package} }));
                    $newPkg->{package} = $dep;
	            $newPkg->{data}->{fetch}->{name} = $dep;
	    	    $newPkg->{data}->{deb}->{prefixSection} = 0;
                    $build = new MUD::Build( package => $newPkg,
                                             config => $self->{config} );
               }
            }

	    # -- If we built, install...
	    #
	    if ($build) {
                $build->build();
                chdir $build->{workdir};
                system("fakeroot dpkg -i --force-depends *.deb");
		croak "Unable to install $dep [$?]\n" if $?;
		$list{$dep} = $build;
            }
        }
	$self->{deps} = \%list;
    }
}


sub clean {
    my $self = shift;

    return unless $self->{deps};
    foreach my $dep (values %{ $self->{deps} }) {
        $dep->clean();
    }
}


sub addSource {
    my $self = shift;
    
    my $store = $self->{package}->{data}->{fetch}->{'deb-src'} || $repo;
    my $file  = $self->{config}->directory('BUILD_DIR', 1).'/sources.list';

    my $data     = '';
    my $input    = -f $file ? $file : '/etc/apt/sources.list';
    my $foundBin = 0;
    my $foundSrc = 0;
    open(IN, "<$input") or croak("Unable to open sources list [$input]: $!\n");
    while(<IN>) {
        s/^\s*deb-src\s+http:\/\/repository\.maemo\.org/#$&/;
        $data .= $_;
        $foundBin ||= /deb\s+$store/;
        $foundSrc ||= /deb-src\s+$store/;
    }
    close(IN);

    $data .= "\ndeb-src $store\n" unless $foundSrc;
    $data .= "\ndeb     $store\n" unless $foundBin;

    open(OUT, ">$file") or croak("Unable to write sources list [$file]: $!\n");
    print OUT $data;
    close(OUT) or croak("Unable to close sources list [$file]: $!\n");

    $self->{sources} = $file;
    $self->apt('update') unless $foundBin and $foundSrc;
}


sub apt {
    my $self = shift;

    my @args = ('apt-get', '-y',
                           '-o', 'Dir::Etc::SourceList='.$self->{sources}, 
                           @_);
    my $data = '';
    unshift @args, 'fakeroot' if -f '/scratchbox/tools/bin/fakeroot';

    warn join(" ", @args)."\n";
    croak("Cannot fork: $!") unless defined(my $pid = open(EXC, "-|"));
    exec(@args) unless $pid;
    while(my $line = <EXC>) {
	$data .= $line;
	print $line;
    }
    close(EXC);

    croak("Error running apt-get @_: $@") if $@;
    return $data;
}


