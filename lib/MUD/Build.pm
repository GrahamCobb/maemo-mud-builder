#
# MUD::Build                                (c) Andrew Flegg 2007
# ~~~~~~~~~~                                Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Build;

use strict;
use vars qw(@ISA $VERSION);
use Carp;
use MUD::Config;
use MUD::Package;

use Data::Dumper;

@ISA     = qw();
$VERSION = '0.10';

sub new {
    my $that = shift;
    $that = ref($that) || $that;

    my $self = bless { @_ }, $that;
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;

    $self->{config} ||= new MUD::Config();
    my $name = $self->{package} or croak("Package not specified.");
    if (ref($name)) {
        $self->{data}    = $name;
        $self->{package} = $name->{package};
    } else {
        $self->{data} = new MUD::Package(config => $self->{config});
 	$self->{data}->load($name);
    }
    print Dumper($self);
}

sub build {
    my $self = shift;

    my $type = 'MUD::Fetch::'.ucfirst($self->{data}->{data}->{fetch}->{type});
    print "$type\n";
    my $fetch = eval("use $type;
                      return new $type( package => \$self->{data},
                                        config => \$self->{config} )");
    croak "Unable to create fetcher [$type]: $@" if $@;

    $fetch->fetch();

    chdir $self->{data}->{build} || '.';
    system("dpkg-buildpackage -rfakeroot -b");
}
