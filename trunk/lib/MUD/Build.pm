#
# MUD::Build                                (c) Andrew Flegg 2007
# ~~~~~~~~~~                                Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Build;

use strict;
use vars qw(@ISA $VERSION);
use Carp;
use File::Path;
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

}

sub build {
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
    chdir $self->{data}->{build} || '.';
    print 'Build dir ['.$self->{data}->{build}."]\n";

    # -- Apply any patches...
    # 
    my $patch = $self->{config}->directory('PACKAGES_DIR').'/patch/'.$self->{package}.'.patch';
    print "+++ Checking patch file [$patch]\n";
    if (-f $patch) {
        system("patch -p0 <$patch");
    }
    
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

    $self->{fetch}->clean();
    system('rm', '-rf', $self->{workdir});
}

sub copy {
    my $self = shift;

    my $output = $self->{config}->directory('UPLOAD_DIR', 1);
    system("cp ".$self->{workdir}."/*.deb $output/");
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
    print Dumper($self);
    my $userSection = $self->{data}->{data}->{deb}->{'prefix-section'};
    $userSection = 1 unless defined($userSection);
    if ($userSection) {
       $control =~ s/^(Section:)\s*(?!user\/)/$1 user\//mg;
    }

    # -- Icon...
    #
    my $iconFile = $self->{config}->directory('PACKAGES_DIR').'/icon/'.$self->{package};
    if (! -f $iconFile and ($self->{data}->{data}->{deb}->{icon} || '') =~ /^https?:.*?\.(\w+)(\?.*)?$/) {
        $iconFile = $self->{workdir}.'/'.$self->{package}.".$1";
	system('wget', '-O', $iconFile, $self->{data}->{data}->{deb}->{icon});
    }

    if (-f $iconFile) {
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
}
