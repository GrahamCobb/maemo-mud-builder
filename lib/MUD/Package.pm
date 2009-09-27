
=head1 NAME

MUD::Package - Define a MUD package, and the data/definitions
               contained within.

=head1 SYNOPSIS

    use MUD::Package;
    my $pkg = MUD::Package->new();
    $pkg->load('vim');
    my $name          = $pkg->name;
    my $iconFile      = $pkg->icon(26);
    my $description   = $pkg->description;
    my $upgradeDesc   = $pkg->upgradeDescription;
    my $displayName   = $pkg->displayName;
    my $bugTracker    = $pkg->bugTracker;
    my $buildDepends  = $pkg->buildDepends;
    my $optify        = $pkg->optify;
    my @patchFiles    = $pkg->patches;
    my $controlFields = $pkg->controlFields;
    my $section       = $pkg->section;
    my $version       = $pkg->version;
    my @extras        = $pkg->extras;
    
    MUD::Package::setField($controlData, 'Section', 'user/network');
    my @values = MUD::Package::parseField($controlData, 'Section');

=head1 DESCRIPTION

This class abstracts L<MUD::Build> from the underlying container
format for MUD packages. This allows for future expansion in changing
the disk structure etc. by changing this class alone. Given a package
name, it will find the various artifacts: XML definition, icons etc.

There are also convenience methods for dealing with Debian control
files, see L</setField> and L</parseField>. 

=head1 METHODS

=over 12

=cut

package MUD::Package;

use strict;
use vars qw(@ISA $VERSION @PERMITTED_SECTIONS);
use XML::Simple;
use Text::Wrap;
use File::Spec;
use File::Temp qw(tempfile);
use File::Basename;
use File::Copy;
use Carp;
use MUD::ExtrasEntry;

@ISA     = qw();
$VERSION = '0.20';

# Based on Maemo Packaging Policy & Debian Policy
@PERMITTED_SECTIONS = qw(accessories communication games multimedia office
                            other programming support themes tools
                            
                            admin comm devel doc editors electronics embedded
                            games gnome graphics hamradio interpreters kde libs
                            libdevel mail math misc net news oldlibs perl python
                            science shells sound tex text utils web x11);

=item new( [ORIGINAL] )

Create a new package instance. This can be optionally
initialised by passing in an existing package as
C<ORIGINAL>.

=cut

sub new {
  my $that = shift;
  $that = ref($that) || $that;

  my $self = bless { @_ }, $that;
  $self->_init();
  return $self;
}


=item _init

Initialise a new instance. Private method.

=cut

sub _init {
  my $self = shift;

  $self->{config} ||= new MUD::Config();
}


=item load( NAME )

Load information for the given package into this object.
This will load an XML file from C<PACKAGES_DIR/name.xml>,
run any SDK-specific XSLT and initialise any environment
variables defined for the build.

=cut

sub load {
  my $self = shift;
  my ($name) = @_;

  # -- Check if it's a new format package...
  #
  my $file = $self->{config}->directory('PACKAGES_DIR') . "/$name.xml";
  if (-f $file) {
    $self->{format} = 1; # Old-style package, spread out
    
  } elsif (-d $name and -f "$name/mud.xml") {
    $self->{format} = 2; # New-format package, outside `packages'
    $self->{basedir} = rel2abs($name).'/';
    $name =~ s!/$!!;
    $file = "$name/mud.xml";
    $name = basename($name);
    
  } elsif (-d $self->{config}->directory('PACKAGES_DIR')."/$name.pkg") {
    $self->{format} = 2; # New-format package, inside `packages'
    $self->{basedir} = $self->{config}->directory('PACKAGES_DIR')."/$name.pkg/";
    $file = $self->{basedir}.'/mud.xml';
    
  } else {
    die "Unknown package [$file]\n";
  }
  
  $name =~ s/\.pkg$//;
    
  # -- Now load the information, applying any XSLT...
  #
  # FIXME: Should do heuristics to work out default sdk name
  my $sdk = $::OPTS{sdk} || 'diablo';

  my $xsl = "$self->{config}->{base}/XSL/SDK.xsl";
  $xsl = $::OPTS{xsl} if $::OPTS{xsl};
  croak("Missing XSLT file: $xsl") unless -f $xsl;

  my $holdTerminator = $/;
  undef $/;
  open(XMLFILE,"xsltproc --stringparam sdk $sdk $xsl $file |") or croak("Unable to perform XSL Transformation on [$file]: $!\nHave you installed xsltproc?");
  $file = <XMLFILE>;
  close(XMLFILE);
  $/ = $holdTerminator;
  
  # Lower case all the tags for normalisation
  $file =~ s!(</?[\w-]+)!lc($1)!egx;

  $self->{data} = XMLin($file) or croak("Unable to parse configuration for '$name': error in [$file]?");
  $self->{name} = $name;
  $self->{sdk}  = $sdk;

  if ($self->{data}->{build}->{env}) {
    while(my ($k, $v) = each %{ $self->{data}->{build}->{env} }) {
      $v =~ s/\$([\w_]+)/$ENV{$1} || ''/egx;
      $ENV{$k} = $v;
    }
  }

  return $self;
}


=item name

Return the package's name.

=cut

sub name {
  my $self = shift;
  
  return $self->{name};
}


=item icon( SIZE )

Return a path to a file containing an icon of the specified
size. If L<ImageMagick> is installed, it will be used to convert
any icon found to the given size (as both width and height).
If multiple icons are available, the one with a filename containing
a number closest to C<SIZE> is used either directly, or as the
resize source.

The file returned will I<not> be within the build directory, and
so cannot be directly used as a reference within C<debian/rules>.

If no appropriate icon can be found, C<undef> is returned.

=cut

sub icon {
  my $self = shift;
  my ($size) = @_;
  
  my $iconFile = $self->{data}->{deb}->{icon};
  if (! -f $iconFile) {
    my $iconDir = $self->{format} == 1 ? $self->{config}->directory('PACKAGES_DIR').'/icon/'
                : $self->{format} == 2 ? $self->{basedir}
                : croak("Unsupported package format");
    foreach my $suffix (("-$size.png", '-26.png', '-32.png', '-40.png', '-48.png', '-64.png', '')) {
      $iconFile = $iconDir.$self->name.$suffix;
      last if -f $iconFile;
    }
  }

  if (! -f $iconFile and ($self->{data}->{deb}->{icon} || '') =~ /^https?:.*?(\.\w+)(\?.*)?$/) {
    (undef, $iconFile) = tempfile("mud-$self->{name}-XXXXX", SUFFIX => $1, UNLINK => 1, DIR => File::Spec->tmpdir);
    system('wget', '-O', $iconFile, $self->{data}->{deb}->{icon});
  }
  
  if (-f $iconFile and $iconFile !~ /-$size\b/) {
    my $sourceIcon = $iconFile;
    (undef, $iconFile) = tempfile("mud-$self->{name}-XXXXX", SUFFIX => ".png", UNLINK => 1, DIR => File::Spec->tmpdir);
    print "+++ Converting [$sourceIcon] to [$iconFile] at ${size}px WxH\n";
    system('convert', $sourceIcon, '-resize', "${size}x${size}", $iconFile);
    copy($sourceIcon, $iconFile) or die "copy failed: $!" unless -s $iconFile;
  }
  
  print "Icon for ${size}x${size} = [$iconFile]\n";
  return undef unless $iconFile and -s $iconFile;
  return $iconFile;
}


=item description

Return this package's description. This can be sourced
from a file, or directly embedded within the XML.

=cut

sub description {
  my $self = shift;
  
  my $description = $self->{data}->{deb}->{description};
  return ref($description) ? &readFile($description->{file}) : $description;
}


=item upgradeDescription

Return the short description of the reason this package has
been updated. This can be sourced from a file, or directly
embedded within the XML.

=cut

sub upgradeDescription {
  my $self = shift;
  
  my $desc = $self->{data}->{deb}->{'upgrade-description'};
  return ref($desc) ? &readFile($desc->{file}) : $desc;
}

=item buildDepends

Return the list of build dependencies if specified.

=cut

sub buildDepends {
  my $self = shift;
  
  return $self->{data}->{deb}->{'build-depends'};
}


=item displayName

Return the name which should be displayed as a human-readable,
user-friendly variant in Application Manager.

=cut

sub displayName {
  my $self = shift;
  
  return $self->{data}->{deb}->{'display-name'};
}

=item bugTracker

Return the URL of the bug tracker.

=cut

sub bugTracker {
  my $self = shift;
  
  return $self->{data}->{deb}->{'bugtracker'};
}



=item patches

Return an array of patch files which should be applied against
the unpacked source before building. If no patches are to be
applied, returns an empty list.

    my @values = $pkg->patches;

=cut

sub patches {
  my $self = shift;
  
  my @patches = ();
  if ($self->{format} == 1) {
    my $patch = $self->{config}->directory('PACKAGES_DIR').'/patch/'.$self->name.'.patch';
    push @patches, $patch if -f $patch;
    
  } elsif ($self->{format} == 2) {
    push @patches, glob($self->{basedir}.'patches/*') if -d $self->{basedir}.'patches';
  }

  return @patches;
}


=item optify

Return true if the package should be automatically "optified". This
will introduce a build-dependency on 'maemo-optify' and ensure the
optification happens after the package has been built.

=cut

sub optify {
  my $self = shift;
  
  return $self->{data}->{deb}->{'optify'};
}


=item controlFields

Return a hash reference of values which contain additional
C<debian/control> fields to set.

    my $values = $pkg->controlFields;

=cut

sub controlFields {
  my $self = shift;
  
  # -- Return if already generated...
  #
  return $self->{controlFields} if $self->{controlFields};
  
  # -- Generate...
  #
  my %data = map { $_ => $self->{data}->{deb}->{$_} }
             grep { $_ !~ /^(icon|prefix-section|optify|library|libdev|upgrade-description|description|display-name|version|bugtracker|build-depends)$/ }
             keys %{ $self->{data}->{deb} };
  $self->{controlFields} = \%data;
  return $self->{controlFields};
}


=item section

Return the section which this package should be in. If no
section is explicitly specified then, for I<non->libraries,
C<user/> is prefixed.

=cut

sub section {
  my $self = shift;
  
  return undef; # TODO
}


=item version [( VERSION )]

Set or return the version number which should be used for this package.
Setting the version number can be done by sub-classes of
L<MUD::Fetch>, if they have managed to work out the version number from
(say) an upstream URL. However, this can I<always> be overridden by
specifying the version in the C<deb> section of the package XML.

=cut

sub version {
  my $self = shift;
  my ($version) = @_;
  $self->{version} = $version if $version;
  
  return $self->{data}->{deb}->{version} || $self->{version};
}


=item extras

Return an array of L<MUD::ExtrasEntry>s which should be 
copied into C<mud-extras> in the source tree, and made available
to the build scripts.

Files in the package's C<extras> directory will be returned here,
with (optional) metadata loaded from C<extras.xml>. 

If the package is the C<.pkg> directory format, the following
special files in the directory - if present - are automatically added
to the returned list:

=over

=item I<package>-26.png =E<gt> C</usr/share/icons/hicolor/26x26/hildon/I<package>.png>

=item I<package>-48.png =E<gt> C</usr/share/icons/hicolor/48x48/hildon/I<package>.png>

=item I<package>-64.png =E<gt> C</usr/share/icons/hicolor/scalable/hildon/I<package>.png>

=item I<package>.desktop =E<gt> C</usr/share/applications/hildon/I<package>.desktop>

=item I<package>.service =E<gt> C</usr/share/applications/hildon/I<package>.desktop>

=back

If no extra files are to be installed, an empty list is returned.

=cut

sub extras {
  my $self = shift;
  my @extras = ();
  
  return () if $self->{format} == 1;
  croak "Unsupported format in extras()" unless $self->{format} == 2;
  
  # -- Look for desktop files and do some automagicification...
  #
  if (-f (my $desktop = $self->{basedir}."$self->{name}.desktop")) {
    push @extras, new MUD::ExtrasEntry($desktop, { path => "/usr/share/applications/hildon/$self->{name}.desktop"} );
    push @extras, new MUD::ExtrasEntry($self->icon(26), { path => "/usr/share/icons/hicolor/26x26/hildon/$self->{name}.png"} );
    push @extras, new MUD::ExtrasEntry($self->icon(48), { path => "/usr/share/icons/hicolor/48x48/hildon/$self->{name}.png"} );
    push @extras, new MUD::ExtrasEntry($self->icon(64), { path => "/usr/share/icons/hicolor/scalable/hildon/$self->{name}.png"} );
    
    if (-f (my $service = $self->{basedir}."$self->{name}.service")) {
      push @extras, new MUD::ExtrasEntry($service, { path => "/usr/share/dbus-1/services/$self->{name}.service"} );
    }
  }
  
  #-- Glob extras and parse extras.xml...
  #
  if (-f (my $extrasFile = $self->{basedir}.'extras.xml') and
      -d (my $extrasDir = $self->{basedir}.'extras')) {
    my $xml = XMLin($extrasFile, ForceArray => qw(destination), KeyAttr => qw(name));
    foreach my $file (glob($extrasDir.'/*')) {
      my $destinations = $xml->{file}->{substr($file, length($extrasDir) + 1)}->{destination};
      if ($destinations) {
        foreach my $destination (@$destinations) {
          push @extras, new MUD::ExtrasEntry($file, $destination)
        }
      } else {
        push @extras, new MUD::ExtrasEntry($file);
      }
    }
  }
  
  return @extras;
}


=item parseField( FIELD, DATA )

Utility method for reading a field from a Debian control file and
returning the array of lines which makes it up.

    my ($value) = MUD::Package::parseField('Version', $controlData);
    
=cut

sub parseField {
  my ($field, $data) = @_;

  my @lines = $data =~ /^[\r\n]+\s?$field:(\s+.*?[\r\n])(\s\s\S.*[\r\n])*/ig;

  if ($field =~ /^(Build-)?Depends$/i) {
    @lines = map { s/\s*[\(\[].*?[\)\]]//; chomp; $_ }
             split /\s*[,|]\s+/, join(", ", @lines);
  }

  return @lines;
}


=item setField( DATA, FIELD, VALUE )

Utility method for setting a field within a Debian control file.
The value of C<DATA> is changed in place; no value is returned.

    MUD::Package::setField($controlData, 'Version', $value);
    
If C<VALUE> is undefined, no change is made to C<DATA>.
    
=cut

sub setField {
  my ($data, $field, $value) = @_;
  return $data if !defined($value);
  
  # Capitalise field name
  $field = ucfirst($field);
  $field =~ s/\b([a-z])/uc($1)/egx;

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

  # Remove a terminating newline
  $value =~ s/(\n)+$//;
  
  my $wrapped = wrap("", "  ", "$field: $value");
  $wrapped =~ s/\n(\s*).?\s*\n/\n$1.\n/g;
  
  # Put the field in the correct paragraph
  my $paragraph = $field =~ /^(Uploaders|Build-Depends|Xsbc-Bugtracker)$/ ? 'Source' : 'Package';
  
  if ($data =~ /^$field:/im) {
    $data =~ s/^$field:\s.*\n([ \t]+\S.*\n)*/$wrapped\n/img or croak "Failed to change field [$field] to [$value] in [$data]";
  } else {
    $data =~ s/^$paragraph: .*$/$&\n$wrapped/mg or croak "Failed to add field [$field] with [$value] in [$data]";
  }
  
  $_[0] = $data;
}


=item readFile( FILE )

Utility method for reading the contents of a file. (Any newlines
in the file are converted into C<\n>. - DISABLED)

=cut

sub readFile {
  my ($file) = @_;
  my $contents = '';

  open(IN, $file) or croak "Unable to read file $file: $!\n";
  while(<IN>) { $contents .= $_ ; }
  close(IN);

  #$contents =~ s/\n/\\n/g;

  return $contents;
}
 

=back

=head1 COPYRIGHT

(c) Andrew Flegg 2007 - 2009. Released under the Artistic Licence:
L<http://www.opensource.org/licenses/artistic-license-2.0.php>

=head1 SEE ALSO

L<http://mud-builder.garage.maemo.org/>
