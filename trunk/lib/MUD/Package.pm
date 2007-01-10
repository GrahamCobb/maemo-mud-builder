#
# MUD::Package                       (c) Andrew Flegg 2007
# ~~~~~~~~~~~~                       Released under the Artistic Licence
#                                    http://mud-builder.garage.maemo.org/

package MUD::Package;

use strict;
use vars qw(@ISA $VERSION);
use XML::Simple;
use Carp;

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
}

sub load {
    my $self = shift;
    my ($name) = @_;

    my $file = $self->{config}->directory('PACKAGES_DIR') . "/$name.xml";

    croak("Unknown package '$name': can't find [$file]") unless -f $file;

    $self->{data} = XMLin($file) or croak("Unable to parse configuration for '$name': error in [$file]?");
    $self->{name} = $name;
}

