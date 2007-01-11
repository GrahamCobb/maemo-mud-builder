#
# MUD::Build                                (c) Andrew Flegg 2007
# ~~~~~~~~~~                                Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Build;

use strict;
use vars qw(@ISA $VERSION);
use Carp;
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
    $fetch->fetch();
    chdir $self->{data}->{build} || '.';

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

    croak "TODO: Unable to generate debian control files for ".$self->{package}." yet.\n";

    my $maintainer = '';
    if (!$maintainer and -f 'AUTHORS') {
        open(IN, "<AUTHORS");
        while(<IN>) {
            s/\t/        /;
	    next unless /(?:\s{2}|:\s)\s*(.*?\@\S+)/;
	    $maintainer = $1;
	    last;
         }
         close(IN);
     }



}
