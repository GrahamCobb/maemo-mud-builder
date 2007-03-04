#
# MUD::Fetch::Tarball                       (c) Andrew Flegg 2007
# ~~~~~~~~~~~~~~~~~~~                       Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Fetch::Tarball;

use strict;
use vars qw(@ISA $VERSION);
use MUD::Fetch::Base;
use Carp;

@ISA     = qw(MUD::Fetch::Base);
$VERSION = '0.10';

sub fetch {
    my $self = shift;

    croak "No URL specfied" unless my $url = $self->{package}->{data}->{fetch}->{url};
   
    my $basename  = $self->{package}->{data}->{fetch}->{file}; 
    $basename   ||= $1 if $url =~ m!^.*?/([^/]+)(\?.*)?$!;

    #Create the download dir if it does not exits
    $basename = $self->{config}->directory("DOWNLOADS_DIR",1) . "/$basename" ;

    my $isOld     = -l $self->{workdir}.'/.build';
    system('wget', '-O', $basename, $url) unless -s $basename;

    croak "Unable to download [$url] to [$basename]\n" unless -f $basename;
    $self->{file} = $basename;

    my @start = <*>;
    $self->unpack($basename);
    my @end = <*>;

    if ($#end > $#start + 1) {
        $self->{package}->{build} ||= '.';
    } else {
        my %s = map { $_ => 1 } @start;
        @end = grep { !$s{$_} } @end;
        $self->{package}->{build} = $end[0];
    }
    $self->{package}->{version} = $1 if $basename =~ /-(\d[\w\-\.]+\w|\d\w*)*$/;

    my @deps = split /\s*,\s*/, ($self->{package}->{data}->{fetch}->{depends} || '');
    foreach my $dep (@deps) {
            my $build;

            # -- Build from one of MUD, existing binaries or upstream source...
            #
            if (-f $self->{config}->directory('PACKAGES_DIR') . "/$dep.xml") {
                $build = new MUD::Build( package => $dep,
					 config  => $self->{config} );

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
            }
    }
}



sub clean {
    my $self = shift;

    #remove the downloaded file only if DOWNLOAD_KEEP false
    #unlink $self->{file} if $self->{config}->{"DOWNLOAD_KEEP"};
}


sub unpack {
    my $self   = shift;
    my ($file) = @_;

    my @args  = ($file);
    $_ = $file;

    if (s/\.tar\.gz$// or s/\.tgz$//) {
	unshift @args, 'tar', 'xzf';

    } elsif (s/\.tar\.bz2$//) {
        unshift @args, 'tar', 'xjf';

    } elsif (s/\.zip$//) {
        unshift @args, 'unzip';

    } else {
        croak "Unknown file extension on [$file]\n";
    }
    $_[0] = $_;

    print "+++ @args\n";
    system @args;
    croak "Failed to unpack [$file]: $@\n" if $@;
}
