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
    my $isOld     = -s $basename;
    system('wget', '-O', $basename, $url) unless $isOld;

    croak "Unable to download [$url] to [$basename]\n" unless -f $basename;
    $self->{file} = $basename;

    my @start = <*>;
    $self->unpack($basename);
    my @end = <*>;
    return if $isOld;

    if ($#end > $#start + 1) {
        $self->{package}->{build} = '.';
    } else {
        my %s = map { $_ => 1 } @start;
        @end = grep { !$s{$_} } @end;
        $self->{package}->{build} = $end[0];
    }

    my @deps = split /\s*,\s*/, ($self->{package}->{data}->{fetch}->{depends} || '');
    foreach my $d (@deps) {
	my $builder = new MUD::Build(package => $d, config => $self->{config});
	$builder->build();
        chdir $builder->{workdir};
	system("fakeroot dpkg -i --force-depends *.deb");
        croak "Unable to install $d [$?]\n" if $?;
    }
}



sub clean {
    my $self = shift;

    unlink $self->{file};
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
