#
# MUD::Build                                (c) Andrew Flegg 2007
# ~~~~~~~~~~                                Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Build;

use strict;
use vars qw(@ISA $VERSION);
use Carp;
use File::Path;
use File::Spec;
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
        $self->{data} = $name;
        $name = $self->{package} = $name->{package};
    } else {
        $self->{data} = new MUD::Package(config => $self->{config});
 	$self->{data}->load($name);
    }
    $self->{workdir} = $self->{config}->directory('BUILD_DIR')."/$name";

    my $buildDir = $self->{workdir}.'/.build';
    $self->{data}->{build} = $buildDir if -d $buildDir;
}

sub build {
    my $self = shift;

    $self->clean();
    $self->fetch();
    $self->patch();
    $self->compile();
}

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

    $self->{data}->{build} = File::Spec->rel2abs($self->{data}->{build} || '.',
                                            $self->{workdir});
    print "Set build dir to [".$self->{data}->{build}."]\n";
    system('ln', '-snf', $self->{data}->{build}, $self->{workdir}.'/.build');
}

sub patch {
    my $self = shift;

    chdir $self->{data}->{build} || croak "Build dir not set.\n";

    # -- Apply any patches...
    # 
    my $patch = $self->{config}->directory('PACKAGES_DIR').'/patch/'.$self->{package}.'.patch';
    print "+++ Checking patch file [$patch]\n";
    if (-f $patch) {
        system("patch -p0 <$patch");
        croak "Failed to apply patch [$?]\n" if $?;
    }
}

sub compile {
    my $self = shift;

    chdir $self->{data}->{build} || croak "Build dir not set.\n";
    
    # -- Generate the Debian control scripts...
    #
    unless (-f 'debian/control') {
        $self->genDebControl();
    }

    # -- Tweak for Maemo compatibility...
    #
    $self->patchDebControl();

    system("dpkg-buildpackage -rfakeroot -b");
}

sub clean {
    my $self = shift;

    $self->{fetch}->clean() if $self->{fetch};
    system('rm', '-rf', $self->{workdir});
}

sub copy {
    my $self = shift;
    my %debs = ();

    my $output = $self->{config}->directory('UPLOAD_DIR', 1);
    print "+++ Calculating dependencies to copy to [$output]\n";
    $self->addDebs(\%debs, $self->{workdir}, '*.deb');
    foreach my $deb (keys(%debs)) {
        system('cp', '-v', $deb, "$output/");
    }
}

sub addDebs {
    my $self = shift;
    my ($ref, $dir, $pattern) = @_;

    my @results = `find '$dir' -type f -name '$pattern'`;
    my @add     = ();
    foreach my $d (@results) {
        chomp($d);
        next if $ref->{$d}++;
        my @deps = MUD::Package->parseField('Depends',
					    scalar(`dpkg --info '$d'`));
        foreach my $p (@deps) {
            $self->addDebs($ref, $self->{config}->directory('BUILD_DIR'),
                                 "${p}_*.deb") unless $ref->{$p};
        }
    }
}

sub genDebControl {
    my $self = shift;

    #croak "TODO: Unable to generate debian control files for ".$self->{package}." yet.\n";

    my $maintainer = '';
    if (!$maintainer and -f 'AUTHORS') {
        open(IN, "<AUTHORS");
        while(<IN>) {
            s/\t/        /;
	    next unless /[\s<:]\s*([^\s\<]+?\@[^\s>]+)/;
	    $maintainer = $1;
            $maintainer =~ s/\.$//;
	    last;
         }
         close(IN);
     }

     my @args = ('dh_make', #'-c', 'unknown',
                            '-e', $maintainer, 
                            '-s',
                            '-n', '-p', $self->{package});
     croak("Cannot fork: $!") unless defined(my $pid = open(EXC, "|-"));
     exec(@args) unless $pid;
     while(<EXC>) {
         print;
         print EXC "\n" if /Hit <enter>/;
     }
     close(EXC);
}


sub patchDebControl {
    my $self = shift;

    my $control = '';
    open(IN, "<debian/control") or croak "Unable to read control: $!\n";
    while(<IN>) { $control .= $_; }
    close(IN);
    my $origControl = $control;

    # -- Fix section...
    #
    my $userSection = $self->{data}->{data}->{deb}->{'prefix-section'};
    $userSection = 1 unless defined($userSection);
    if ($userSection) {
       $control =~ s/^(Section:)\s*(?!user\/)/$1 user\//mg;
    }

    # -- Fix dependencies...
    #
    $control =~ s/\${perl:Depends}//g;

    # -- Icon...
    #
    my $iconFile = $self->{config}->directory('PACKAGES_DIR').'/icon/'.$self->{package};
    if (! -f $iconFile and ($self->{data}->{data}->{deb}->{icon} || '') =~ /^https?:.*?\.(\w+)(\?.*)?$/) {
        $iconFile = $self->{workdir}.'/'.$self->{package}.".$1";
	system('wget', '-O', $iconFile, $self->{data}->{data}->{deb}->{icon});
    }

    if (-f $iconFile and $control !~ /^XB-Maemo-Icon-26:/im) {
        system('convert', $iconFile, '-resize', '26x26', $iconFile);
        my $iconData = `uuencode -m icon <$iconFile`;
        $iconData =~ s/^begin-base64 \d{3,4} icon[\s\r\n]+//m;
	$iconData =~ s/^/  /mg;
        $control .= "XB-Maemo-Icon-26:$iconData";
    }

    if ($control ne $origControl) {
        print $control;
        open(OUT, ">debian/control") or croak "Unable to write control: $!\n";
        print OUT $control;
        close(OUT) or croak "Unable to close control: $!\n";
    }

    # -- Patch other miscellaneous problems...
    #
    system('echo 4 >debian/compat');
}
