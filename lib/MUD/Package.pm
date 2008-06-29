#
# MUD::Package                       (c) Andrew Flegg 2007
# ~~~~~~~~~~~~                       Released under the Artistic Licence
#                                    http://mud-builder.garage.maemo.org/

package MUD::Package;

use strict;
use vars qw(@ISA $VERSION @PERMITTED_SECTIONS);
use XML::Simple;
use Text::Wrap;
use Carp;

@ISA     = qw();
$VERSION = '0.10';

# Based on Maemo Packaging Policy & Debian Policy
@PERMITTED_SECTIONS = qw(accessories communication games multimedia office
                            other programming support themes tools
                            
                            admin comm devel doc editors electronics embedded
                            games gnome graphics hamradio interpreters kde libs
                            libdevel mail math misc net news oldlibs perl python
                            science shells sound tex text utils web x11);

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

    croak "Package names must be lowercase.\n" if lc($name) ne $name;
    my $file = $self->{config}->directory('PACKAGES_DIR') . "/$name.xml";
    croak("Unknown package '$name': can't find [$file]") unless -f $file;

    # FIXME: Should do heuristics to work out default sdk name
    my $sdk = "diablo";

    $sdk = $::OPTS{sdk} if $::OPTS{sdk};

    my $xsl = "$self->{config}->{base}/XSL/SDK.xsl";
    $xsl = $::OPTS{xsl} if $::OPTS{xsl};
    croak("Missing XSLT file: $xsl") unless -f $xsl;

    my $holdTerminator = $/;
    undef $/;
    open(XMLFILE,"xsltproc --stringparam sdk $sdk $xsl $file |") or croak("Unable to perform XSL Transformation on [$file]: $!\nHave you installed xsltproc?");
    $file = <XMLFILE>;
    close(XMLFILE);
    $/ = $holdTerminator;

    $self->{data} = XMLin($file) or croak("Unable to parse configuration for '$name': error in [$file]?");
    $self->{name} = $name;

    if ($self->{data}->{build}->{env}) {
        while(my ($k, $v) = each %{ $self->{data}->{build}->{env} }) {
            $v =~ s/\$([\w_]+)/$ENV{$1} || ''/egx;
            $ENV{$k} = $v;
        }
    }

    return $self;
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

    # Auto-escape the first line break in Description
    $value =~ s/\n/\\n/ if $field eq 'Description' and $value !~ /\\n/;
    
    # Escape blank-lines
    $value =~ s/^\s*.\s*$/\\n\\n/mg;
    
    # Clobber white-space from the XML file for reformatting.
    $value =~ s/[\s\t\r\n]+/ /sg;
    $value =~ s/^[\s\r\t\n]+//;
    $value =~ s/[\s\r\t\n]+$//;

    # Convert '\n' to a newline
    $value =~ s/(\\n)+ */\n/g;
    
    my $wrapped = wrap("", "  ", "$field: $value");
    $wrapped =~ s/\n(\s*)\n/\n$1.\n/g;
    
    # Put the field in the correct paragraph
    my $paragraph = $field eq 'Uploaders' ? 'Source' : 'Package';
    
    if ($data =~ /^$field:/im) {
        $data =~ s/(\n?\s?)$field:([ \t]+[^\n]+\n)*/$1$wrapped\n/ig;
    } else {
        $data =~ s/^$paragraph: .*$/$&\n$wrapped/mg;
    }
    
    return $data;
}
 
