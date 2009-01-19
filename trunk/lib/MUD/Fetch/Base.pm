
=head1 NAME

MUD::Fetch::Base - Parent class for MUD fetch helpers.

=cut 

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

sub clean {
    my $self = shift;

    warn "Unimplemented clean.\n";
}


=head1 COPYRIGHT

(c) Andrew Flegg 2007 - 2009. Released under the Artistic Licence:
L<http://www.opensource.org/licenses/artistic-license-2.0.php>

=head1 SEE ALSO

L<http://mud-builder.garage.maemo.org/>
