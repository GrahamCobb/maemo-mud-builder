
=head1 NAME

MUD::ExtrasEntry - definition of file to be copied to mud-extras, and
                   possibly auto-installed.

=head1 DESCRIPTION

This class encapsulates the information on files which should be copied
to C<mud-extras> in the source tree of a package. These files are then
available to C<debian/rules>, and other build scripts, to do with as
they please.

One typical use is to add new files which should be installed alongside
the package, for example icons; launch scripts; desktop files and services.

=head1 METHODS

=over 12

=cut 

package MUD::ExtrasEntry;

use strict;
use Carp;
use vars qw(@ISA $VERSION $SOURCE_DIR);

@ISA        = qw();
$VERSION    = '0.10';
$SOURCE_DIR = 'mud-extras';


=item new( FILE, [ METADATA ] )

Create a new instance of a file which should be copied to the
source tree. C<FILE> should be an absolute path, and 
C<METADATA> is an optional hash of data to define
destination mode, location etc.

C<METADATA> can contain:

=over 10

=item path

Destination path in the target package. Required if the
file is to be auto-added to C<debian/rules:install>.

=item mode

Target file mode. See L</mode> for more information.
Defaults to C<auto>.

=item owner

User ID for the target file. Defaults to C<root>.

=item group

Group for the target file. Defaults to C<root>.

=back

=cut

sub new {
  my $that = shift;
  $that = ref($that) || $that;

  my $self = bless {}, $that;
  ($self->{file}, $self->{data}) = @_;
  $self->_init();

  return $self;
}


=item _init

Check that the given file exists and load any additional
meta-data. Private method.

=cut

sub _init {
  my $self = shift;

  croak "Unable to find file [$self->{file}]" unless -f $self->{file};
  $self->{data}->{mode}  ||= 'auto';
  $self->{data}->{owner} ||= 'root';
  $self->{data}->{group} ||= 'root';
  return $self;
}


=item source

Return the absolute file which is the source of the file
to be copied.

=cut

sub source {
  my $self = shift;
  return $self->{file};
}


=item target( [FILE] )

Set or return the path which the file should be installed to on
the target system.

If not explicitly called, this will be auto-determined from
the information given at construction.

If I<undef> if returned, this file should not be auto-installed, just
copied to C<mud-extras>.

=cut

sub target {
  my $self = shift;
  my ($file) = @_;

  $self->{target}   = $file if defined($file);
  $self->{target} ||= $self->{data}->{path};
  return $self->{target};
}


=item mode

Return the mode for the target file. This should be in the format
C<0644>, suitable for passing to L<install(1)>.

The default is I<auto>, which means C<0644> unless the file starts
with the bytes C<#!> - in which case C<0755> is used.

=cut

sub mode {
  my $self = shift;

  if ($self->{data}->{mode} eq 'auto') {
    my $mode = '0644';
    open my $fh, "<$self->{file}" or die "Unable to read [$self->{file}]: $!\n";
    my $bytes;
    read $fh, $bytes, 2;
    close $fh;

    $mode = '0755' if $bytes eq '#!';
    $self->{data}->{mode} = $mode;
  }

  return $self->{data}->{mode};
}


=item owner

Return the user ID for the target file.

=cut

sub owner {
  my $self = shift;
  
  return $self->{data}->{owner};
}


=item group

Return the group ID for the target file.

=cut

sub group {
  my $self = shift;
  
  return $self->{data}->{group};
}


=head1 COPYRIGHT

(c) Andrew Flegg 2007 - 2009. Released under the Artistic Licence:
L<http://www.opensource.org/licenses/artistic-license-2.0.php>

=head1 SEE ALSO

L<MUD::Package/extraFiles>
L<http://mud-builder.garage.maemo.org/>
