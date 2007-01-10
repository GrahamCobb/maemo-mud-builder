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

    print "Debian fetch!\n";
    $self->addSource();

    my $name     = $self->{package}->{package};
    my $upstream = $self->{package}->{data}->{fetch}->{name} || $name;
    my $buildDir = $self->{config}->directory('BUILD_DIR')."/$name";
    mkdir $buildDir unless -d $buildDir;
    chdir $buildDir;

    my $out = $self->apt('source', $upstream);
    my ($d) = $out =~ /extracting $upstream in ([\w\-\.]+)$/im;
    croak "Couldn't find extract directory!\n" unless $d;
    $self->{package}->{build} = $buildDir."/$d";

    chdir $d;
    my $deps = `dpkg-checkbuilddeps 2>&1`;
    if ($?) {
        $deps =~ s/.*Unmet build dependencies: //is;
        my @list = split /[\s\r\n]+/, $deps;
	print "Need extra deps: @list\n";
        foreach my $dep (@list) {
	    next unless $dep =~ /^\w/;
            system('fakeroot', 'apt-get', '-y', 'install', $dep);
	    my $dpkg = `dpkg -s $dep 2>/dev/null`;
            if ($dpkg !~ /Status: install ok installed/) {
                my $newPkg = new MUD::Package( (%{ $self->{package} }));
                $newPkg->{package} = $dep;
	        $newPkg->{data}->{fetch}->{name} = $dep;
	        print Dumper($newPkg);
                my $build  = new MUD::Build( package => $newPkg,
                                             config => $self->{config} );
                $build->build();
		system("fakeroot dpkg -i $dep *.deb");
            }
        }
    }
}


sub addSource {
    my $self = shift;
    
    my $store = $self->{package}->{data}->{fetch}->{'deb-src'} || $repo;
    print "Looking for [$store]\n";

    my $file = $self->{config}->directory('BUILD_DIR', 1).'/sources.list';

    my $data     = '';
    my $input    = -f $file ? $file : '/etc/apt/sources.list';
    my $foundBin = 0;
    my $foundSrc = 0;
    open(IN, "<$input") or croak("Unable to open sources list [$input]: $!\n");
    while(<IN>) {
        $data .= $_;
        $foundBin ||= /deb\s+$store/;
        $foundSrc ||= /deb-src\s+$store/;
    }
    close(IN);

    $data .= "\ndeb     $store\n" unless $foundBin;
    $data .= "\ndeb-src $store\n" unless $foundSrc;

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

    print join(" ", @args)."\n";
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


