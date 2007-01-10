#
# MUD::Config                               (c) Andrew Flegg 2007
# ~~~~~~~~~~~                               Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Config;

use strict;
use vars qw(@ISA $VERSION);
use File::Spec;
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
    my $file = $self->{file} || 'config';

    $self->{config} = {};
    open(IN, "<$file") or carp("Unable to open [$file]: $!");
    while(<IN>) {
	chomp;
	next unless my ($k, $v) = /^\s*([\w_]+)\s*=\s*(.*)$/;
	$self->{config}->{$k} = $v;
    }
    close(IN);
}

sub option {
    my $self = shift;
    my ($param) = @_;

    return $self->{config}->{$param};
}

sub directory {
    my $self = shift;
    my ($param, $create) = @_;

    my $value = $self->{config}->{$param};
    $value = lc($1) if !$value and $param =~ /^([\w+_]+?)(_DIR)$/i;

    my $base = $self->{base} || File::Spec->curdir();
    my $dir  = File::Spec->rel2abs($value, $base);

    mkdir($dir) if $create and ! -d $dir;
    return $dir;
}
