#
# MUD::Fetch::Debian                        (c) Andrew Flegg 2007
# ~~~~~~~~~~~~~~~~~~                        Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Fetch::Debian;

use strict;
use vars qw(@ISA $VERSION);
use MUD::Fetch::Base;

@ISA     = qw(MUD::Fetch::Base);
$VERSION = '0.10';

our $repo = 'http://ftp.debian.org/ etch main';

sub fetch {
    my $self = shift;

    print "Debian fetch!\n";
    $self->addSource();
}


sub addSource {
    my $self = shift;
    
    my $store = $self->{package}->{'deb-src'} || $repo;
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

    system('echo', 'fakeroot', 
            'apt-get', '-o',
                       'Dir::Etc::SourceList='.$self->{sources},
                       @_
    );

    croak("Error running apt-get @_: $@") if $@;
}


