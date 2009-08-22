
=head1 NAME

MUD::Build - Build packages suitable for upload

=head1 SYNOPSIS

    use MUD::Build;
    my $mud = MUD::Build->new( package => 'vim' );
    $mud->build();

=head1 DESCRIPTION

This class is primarily responsible for controlling the build process
used by C<mud>.

=head1 METHODS

=over 12

=cut

package MUD::Build;

use strict;
use utf8;
use locale;
use vars qw(@ISA $VERSION @PREVENT_INSTALL $DPKG_BUILDPACKAGE $GTK_ICON_CACHE_REFRESH); 
use Carp;
use File::Basename;
use File::Path;
use File::Spec;

use MUD::Config;
use MUD::Package;

use Data::Dumper;

@ISA     = qw();
$VERSION = '0.10';
@PREVENT_INSTALL = qw(changelogs docs examples info man);

# Use -i to ignore .svn directories(among others)
$DPKG_BUILDPACKAGE      = 'dpkg-buildpackage -d -rfakeroot -i -sa -us -uc';
$GTK_ICON_CACHE_REFRESH = 'gtk-update-icon-cache -f /usr/share/icons/hicolor';


=item new( OPTS )

Create a new instance. OPTS is a hash containing name/value pairs:

=over 10

=item package

Name of the package. This is required.  This can either a 
L<MUD::Package> I<reference>, or the name of a package. The use of
reference passing is used when doing recursive, dependency builds.

=back

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
    my $name = $self->{package} or croak("Package not specified.");
    if (ref($name)) {
        $self->{data} = $name;
        $name = $self->{package} = $name->{package};
    } else {
        $self->{data} = new MUD::Package(config => $self->{config});
        $self->{data}->load($name);
    }
    $self->{workdir} = $self->{config}->directory('BUILD_DIR')."/$name";

    my $buildDir = $self->{workdir}.'/.build';
    $buildDir = readlink($buildDir) if -l $buildDir;
    print "Build dir = [$buildDir]\n";
    $self->{data}->{build} = $buildDir if -d $buildDir;

    $ENV{'MUD_PACKAGES_DIR'} = $self->{config}->directory('PACKAGES_DIR');
    $ENV{'MUD_PACKAGES_RELDIR'} = File::Spec->abs2rel($ENV{'MUD_PACKAGES_DIR'}, $self->{workdir}.'/.build');
}


=item build

Build the configured package and place the deb files ready for upload
in the C<uploads/> directory.

=cut 

sub build {
    my $self = shift;

    # Don't build more than once in the same command
    print "***Already built $self->{package}***\n" if %::built->{$self->{package}};
    return if %::built->{$self->{package}}++;

    $self->clean();
    $self->fetch();
    $self->patch();
    $self->compile();
    $self->source();
}


=item fetch

Download the source for the package and unpack it in the build directory.

=cut

sub fetch {
    my $self = shift;

    # -- Instantiate the right fetcher...
    #
    my $type = 'MUD::Fetch::'.ucfirst($self->{data}->{data}->{fetch}->{type});
    print "$type\n";
    my $fetch = eval("use $type;
                      return new $type( package => \$self->{data},
                                        workdir => \$self->{workdir},
                                        config => \$self->{config} )");
    croak "Unable to create fetcher [$type]: $@" if $@;
    $self->{fetch} = $fetch;

    # -- Download and unpack it...
    #
    print "Workdir [".$self->{workdir}."]\n";
    mkpath($self->{workdir}, 1) unless -d $self->{workdir};
    chdir $self->{workdir};
    $fetch->fetch();

    # Note: fetch might change directory while dealing with dependencies,
    # so reset
    chdir $self->{workdir};
    my $buildDir = basename($self->{data}->{build} || '.');
    my $origBDir = $buildDir;
    $buildDir    =~ s/-src\b//;
    my $version  = $self->{data}->version;
    print "Version = $version, buildDir = $buildDir\n";
    $version   ||= $1 if $buildDir =~ s/-(\d[\w\-\.\+\:]+\w|\d\w*)*$//;
    $version   ||= $1 if !$version and $buildDir =~ s/(\d+)$//;
    $version     = $self->{data}->version || $version;
    $version   ||= 1;
    print "Version = $version, buildDir = $buildDir\n";
    $buildDir    = $self->{package} unless $buildDir =~ /^[a-z0-9\-\+]+$/;

    my $versionForBuild = $version;
    $versionForBuild =~ s/-[^-]+$//g;
    $buildDir   .= "-$versionForBuild";
    print "Build dir = $buildDir\n";
    rename $origBDir, $buildDir if $origBDir ne $buildDir;

    $self->{data}->version($version);
    $self->{data}->{build} = File::Spec->rel2abs($buildDir, $self->{workdir});
    print "Set build dir to [".$self->{data}->{build}."]\n";
    system('ln', '-snf', $self->{data}->{build}, $self->{workdir}.'/.build');

    chdir $self->{data}->{build} || croak "Build dir not set.\n";

    # -- Generate the Debian control scripts...
    #
    unless (-f 'debian/control') {
        $self->genDebControl();
    }
}


=item patch

Apply any patches for the given package and modify Debian control structures
to apply to the Maemo SDK. 

=cut

sub patch {
    my $self = shift;

    chdir $self->{data}->{build} || croak "Build dir not set.\n";

    # -- Apply any patches...
    #
    foreach my $patch ($self->{data}->patches) { 
      print "+++ Applying patch file [$patch]\n";
      system("patch -p0 <$patch");
      croak "Failed to apply patch [$?]\n" if $?;
    }

    # -- Remove documentation...
    #
    my $include = $self->{data}->{data}->{build}->{include} || '';
    $include =~ s/\W+/|/g;
    $include = "|$include|";

    my @replace = grep { $include !~ /\|$_\|/ } @PREVENT_INSTALL;
    my $rules = '';
    open(IN, "<debian/rules") or croak "Unable to open debian/rules: $!\n";
    while(<IN>) { $rules .= $_; }
    close(IN);
    my $origRules = $rules;

    print "+++ Preventing install of [".join(',', @replace)."] in deb.\n";
    $rules =~ s/^(\s+dh_install$_\b.*)$/#$1/mg foreach @replace;

    # -- Include dh_install...
    #
    $rules =~ s/^\s*#\s*dh_install\s*$/\tdh_install --sourcedir=debian\/tmp/mg;

    # -- Append configure flags...
    #
    my $append = $self->{data}->{data}->{build}->{'configure-append'} || '';
    print "+++ Appending [$append] to configure.\n";
    $rules =~ s/([\b\s]\.\/configure[\b\s].*?)([\r\n]+?\s*[\r\n]+?)/$1 $append$2/sg if $append;
    
    # -- Copy in any extra files and install...
    #
    if (my @extras = $self->{data}->extras) {
      mkdir $MUD::ExtrasEntry::SOURCE_DIR;
      my @install = ();
      my ($dir) = $rules =~ /^install:.*?# Add here commands to install the package into (.*?)\.$/ms;
      my $installedIcon = 0; 
      
      foreach my $file (@extras) {
        File::Copy::copy($file->source, $MUD::ExtrasEntry::SOURCE_DIR);
        my $target = $file->target;
        next unless $target;
        
        $target =~ s!^/!!;
        
        push @install, 'install -D -m '.$file->mode.
                                 ' -o '.$file->owner.
                                 ' -g '.$file->group.
                                 ' "'.$MUD::ExtrasEntry::SOURCE_DIR.'/'.basename($file->source).'"'.
                                 ' "'.$dir.'/'.$target.'"';
                                 
        $installedIcon = 1 if $target =~ m!^usr/share/icons/hicolor/!;
      }
      
      $rules =~ s{^\tdh_installdirs\n$}{ "$&\t".join("\n\t", @install)."\n" }gme;
      
      # Ensure postinst refreshes the icon cache
      if ($installedIcon) {
        if (-f "debian/postinst") {
          open(OUT, ">>debian/postinst") or croak "Unable to append to postinst: $!\n";
        } else {
          open(OUT, ">debian/postinst") or croak "Unable to create postinst: $!\n";
          print OUT "#!/bin/sh\n";
        }
        print OUT "$GTK_ICON_CACHE_REFRESH\n";
        close(OUT);
        chmod 0755, "debian/postinst";
      }
    }

    # -- Write back debian/rules...
    #
    if ($origRules ne $rules) {
        open(OUT, ">debian/rules") or croak "Can't write debian/rules: $!\n";
        print OUT $rules;
        close(OUT);
    }
}


=item compile

Build the unpacked, and potentially patched, binaries.

=cut

sub compile {
    my $self = shift;

    chdir $self->{data}->{build} || croak "Build dir not set.\n";

    # -- Tweak for Maemo compatibility...
    #
    $self->patchDebControl();
    
    # First build: build binaries and get build-deps
    my $dpkg_depcheck = 'dpkg-depcheck -m -o ../build.deps';
    $dpkg_depcheck ='' if $self->{data}->{sdk} =~ /(bora|gregale)/;
    
    system("$dpkg_depcheck $DPKG_BUILDPACKAGE | tee ../log");
    
    # Modify debian/control with calculated build-depends if not explicitly set
    unless (!$dpkg_depcheck || $self->{data}->{data}->{deb}->{'build-depends'}) {
      my @buildDeps = ();
      if (open(LOG, "<../build.deps")) {
          my $inNeeded = 0;
          while (<LOG>) {
              $inNeeded ||= /^Packages needed:$/;
              next unless $inNeeded and m/^  ([^\s\r\n]+)$/;
              push @buildDeps, $1 if $1 ne $self->{data}->name;
          }
          close(LOG);
      }

      if (@buildDeps) {
          print "Adding calculated build-deps of [".join(', ', @buildDeps)."]\n";
          my $control = $self->readDebControl();
          MUD::Package::setField($control, "Build-Depends", join(', ', @buildDeps));
          $self->writeDebControl($control);
      }
    }
}


=item source

Build the unpacked, and potentially patched, source packages ready
for upload to the autobuilder.

At the moment, no check is made that a compile step is done previously,
however this is seriously recommended to ensure that the auto-calculation
of C<Build-Depends> is done correctly.

=cut

sub source {
    my $self = shift;

    chdir $self->{data}->{build} || croak "Build dir not set.\n";

    # Now build source package for upload
    system("$DPKG_BUILDPACKAGE -S | tee -a ../log"); 
}


=item clean

Remove the build directory and any temporary files used therein.

=cut

sub clean {
    my $self = shift;

    $self->{fetch}->clean() if $self->{fetch};
    system('rm', '-rf', $self->{workdir});
}


=item copy

Copy output files - including debs, tarballs, dsc and changes files - to
the upload directory.

=cut

sub copy {
    my $self = shift;
    my %debs = ();

    my $output = $self->{config}->directory('UPLOAD_DIR', 1);
    print "+++ Calculating dependencies to copy to [$output]\n";
    $self->addDebs(\%debs, $self->{workdir}, '*');
    foreach my $deb (keys(%debs)) {
        system('cp', '-v', $deb, "$output/");
    }
}

sub addDebs {
    my $self = shift;
    my ($ref, $dir, $pattern) = @_;

    print "Finding debs for [$pattern] in [$dir]\n";
    my @results = `find '$dir' -type f -name '$pattern.deb' -o -name '${pattern}_source.changes' -o -name '$pattern.dsc' -o -name '$pattern.tar.gz' -o -name '$pattern.diff.gz'`;
    my @add     = ();
    foreach my $d (@results) {
        chomp($d);
        next if $ref->{$d}++ or $d !~ /\.deb$/;
        my @deps = MUD::Package->parseField('Depends', scalar(`dpkg --info '$d'`));
        foreach my $p (@deps) {
            $self->addDebs($ref, $self->{config}->directory('BUILD_DIR'),
                                 "${p}_*") unless $ref->{$p};
        }
    }
}

sub genDebControl {
    my $self = shift;

    my $maintainer = $self->{data}->{data}->{deb}->{'maintainer'};
    if (!$maintainer and -f 'AUTHORS') {
        open(IN, "<AUTHORS");
        while(<IN>) {
            s/\t/        /;
            next unless m/((?:[^a-z][^!-\/:-@\[-`]+ )+\s*<?\s*[^\s\<]+?\@[^\s>]+\s*>?)/ or
                         m/[\s<:]\s*([^\s\<]+?\@[^\s>]+)/;
            $maintainer = $1;
            $maintainer =~ s/\.$//;
            last;
         }
         close(IN);
     }

    # `debian/changelog' must not contain an empty address.
    $maintainer = 'MUD Build Team <mud-builder-users@garage.maemo.org>' if !$maintainer;

    print "maintainer = [$maintainer]\n";
    if ($maintainer =~ /^\s*(.*?)\s*<\s*(.*@.*?)\s*>/ ) {
        $ENV{'DEBFULLNAME'} = $1;
        $maintainer = $2;
    }
    $ENV{'DEBFULLNAME'} ||= 'Unknown';
    
    my $type = $self->{package} =~ /^lib/ ? 'l' : 's';
    $type = $1 if ($self->{data}->{data}->{build}->{result} || '') =~ /^(.)/;
    my @args = ('dh_make', 
                           '-e', $maintainer, 
                           "-$type",
                           '-n', '-p', $self->{package});
    my $licence = $self->{data}->{data}->{build}->{'copyright'};
    push @args, '-c', $licence if $licence;
                           
    croak("Cannot fork: $!") unless defined(my $pid = open(EXC, "|-"));
    exec(@args) unless $pid;
    while(<EXC>) {
        print;
        print EXC "\n" if /Hit <enter>/;
    }
    close(EXC);

    # Make dh_make 0.37 work like dh_make 0.38
    # include 'usr/share/pkgconfig/*' in debian/lib...-dev.install
    my $libdevinstall = "debian/".$self->{package}."-dev.install";
    if ($type == 'l' and -f $libdevinstall) {
      # print "Checking $libdevinstall\n";
    	open(IN, "<$libdevinstall") or croak "Unable to read $libdevinstall: $!\n";
      my (@contents) = <IN>;
    	close(IN);
      if ( grep m#^usr/share/pkgconfig/\*$#, @contents ) {
        # print "usr/share/pkgconfig/* already included\n";
      } else {
        print "Adding usr/share/pkgconfig/* to $libdevinstall\n";
        open(OUT, ">>$libdevinstall") or croak "Unable to append to $libdevinstall: $!\n";
        print OUT "usr/share/pkgconfig/*\n";
        close OUT;
      }
    }

    # Make dh_make 0.38 and earlier work like dh_make 0.42
    # MAKE install var=xx => MAKE var=xx install
    system('sed','-i','debian/rules','-e','/$(MAKE) install ./s/\(install\) \(.*\)/\2 \1/');

    foreach my $f (<debian/*.files>) {
        my $i = $f;
        $i =~ s/\.files$/\.install/;
        rename $f, $i;
    }
}

sub readDebControl {
    my $self = shift;
    my $control = '';
    open(IN, "<debian/control") or croak "Unable to read control: $!\n";
    while(<IN>) { $control .= $_; }
    close(IN);
    
    return $control;
}


sub writeDebControl {
    my $self = shift;
    my ($control) = @_;
      
    print $control;
    rename "debian/control", "debian/control.mud";
    open(OUT, ">debian/control") or croak "Unable to write control: $!\n";
    print OUT $control;
    close(OUT) or croak "Unable to close control: $!\n";
}

sub patchDebControl {
    my $self = shift;

    my $control = $self->readDebControl();
    my $origControl = $control;

    # -- Fix standards version and uploaders...
    #
    $control =~ s/^(Section:.*)devel/$1libdev/;
    MUD::Package::setField($control, 'Standards-Version', '3.6.1');
    MUD::Package::setField($control, 'Uploaders', 'MUD Project <mud-builder-team@garage.maemo.org>');

    # -- Fix "BROKEN" libraries...
    #
    my $name = $self->{package};
    my $libname = $self->{data}->{data}->{deb}->{'library'} || "${name}1";
    $control =~ s/\Q${name}\EBROKEN/${libname}/mgi;

    # -- Fix lib-dev package name
    #
    my $libdevname = $self->{data}->{data}->{deb}->{'libdev'} || "${name}-dev";
    $control =~ s/\Q${name}\E-dev/${libdevname}/mgi;

    # -- Fix section...
    # TODO Use $self->{data}->section
    my $userSection = defined ($self->{data}->{data}->{deb}->{'prefix-section'}) 
        ? $self->{data}->{data}->{deb}->{'prefix-section'} : $self->{package} !~ /^lib/;
        
    $control =~ s/^(Section:)\s*(user\/)*(.*)$/$1 user\/$3/mig if $userSection;

    # -- Fix dependencies...
    #
    $control =~ s/\${perl:Depends}//g;

    # -- Icon(s)...
    #
    my $iconFile = $self->{data}->icon(26);
    if ($iconFile and $control !~ /^XB-Maemo-Icon-26:/im) {
        my $iconData = `uuencode -m icon <\Q${iconFile}\E`;
        $iconData =~ s/^begin-base64 \d{3,4} icon[\s\r\n]+//m;
        $iconData =~ s/^/  /mg;
        if ($iconData) {
            chomp($iconData);
            $control =~ s/^Package: .*$/$&\nXB-Maemo-Icon-26:$iconData/mg;
        }
    }

    # -- Description...
    #
    MUD::Package::setField($control, "Description", $self->{data}->description);

    # -- Upgrade Description...
    #
    MUD::Package::setField($control, "XB-Maemo-Upgrade-Description", $self->{data}->upgradeDescription);

    # -- Display Name...
    #
    MUD::Package::setField($control, "XB-Maemo-Display-Name", $self->{data}->displayName);

    # -- Other control fields...
    #
    while (my ($k, $v) = each %{ $self->{data}->controlFields }) {
        MUD::Package::setField($control, $k, $v);
    }

    $self->writeDebControl($control) if $control ne $origControl;
    
    # -- Modify changelog to contain this build...
    #
    # debchange doesn't do anything if the version is already there except moan
    system('debchange', '-v', $self->{data}->version,
                        '-p', '--noquery',
                        'Build using mud-builder by '.($ENV{USER} || 'unknown'));

    # -- Patch other miscellaneous problems...
    #
    system('echo 4 >debian/compat');
}

=back

=head1 COPYRIGHT

(c) Andrew Flegg 2007 - 2009. Released under the Artistic Licence:
L<http://www.opensource.org/licenses/artistic-license-2.0.php>

=head1 SEE ALSO

L<http://mud-builder.garage.maemo.org/>
