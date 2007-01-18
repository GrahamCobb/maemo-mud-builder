#
# MUD::Package                       (c) Andrew Flegg 2007
# ~~~~~~~~~~~~                       Released under the Artistic Licence
#                                    http://mud-builder.garage.maemo.org/

package MUD::Package;

use strict;
use vars qw(@ISA $VERSION);
use XML::Simple;
use Text::Wrap;
use File::Basename;
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
    if (-f $name) {
        print "+++ Got file [$name]\n";
        $file = $name;
        $name = basename($file, ".xml");
    }

    croak("Unknown package '$name': can't find [$file]") unless -f $file;

    $self->{data} = XMLin($file) or croak("Unable to parse configuration for '$name': error in [$file]?");
    $self->{name} = $name;
}

sub parseField {
    my $self = shift;
    my ($field, $data) = @_;

    my @lines = $data =~ /[\r\n]+\s?$field:(\s+.*?[\r\n])(\s\s\S.*[\r\n])*/ig;

    if ($field =~ /^(Build-)?Depends$/i) {
        @lines = map { s/\s*[\(\[].*?[\)\]]//; chomp; $_ }
                      split /\s*[,|]\s+/, join(", ", @lines);
    }

    return @lines;
}

sub setField {
    my $self = shift;
    my ($data, $field, $value) = @_;

    $value =~ s/^[\s\r\n]+//;
    $value =~ s/[\s\r\n]+$//;
    $value =~ s/\\n/\n/g;
    my $wrapped = wrap("", "  ", "$field: $value");
    if ($data =~ /[\r\n]+\s?$field:/i) {
        $data =~ s/([\r\n]+\s?)$field:(\s+[^\r\n]*[\r\n])*/$1$wrapped\n/sig;
    } else {
        $data .= "$wrapped\n";
    }

    return $data;
}
 
