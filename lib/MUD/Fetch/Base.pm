#
# MUD::Fetch::Base                          (c) Andrew Flegg 2007
# ~~~~~~~~~~~~~~~~                          Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Fetch::Base;

use strict;
use MUD::Config;
use vars qw(@ISA $VERSION);

@ISA     = qw();
$VERSION = '0.10';

sub new {
    my $that = shift;
    $that = ref($that) || $that;

    my $self = bless { @_ }, $that;
    $self->{config} ||= new MUD::Config();
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;

    warn "Unimplemented _init.\n";
}

sub fetch {
    my $self = shift;

    warn "Unimplemented fetch.\n";
}
