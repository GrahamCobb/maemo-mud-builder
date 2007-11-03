#
# MUD::Fetch::Command                       (c) Andrew Flegg 2007
# ~~~~~~~~~~~~~~~~~~~                       Relased under the Artistic Licence
#                                           http://mud-builder.garage.maemo.org/

package MUD::Fetch::Command;

use strict;
use vars qw(@ISA $VERSION);
use MUD::Fetch::Base;
use Carp;

@ISA     = qw(MUD::Fetch::Base);
$VERSION = '0.10';

sub fetch {
    my $self = shift;

    croak "No command specfied" unless my $cmd = $self->{package}->{data}->{fetch}->{command};
  
    print "+++ Executing [$cmd]...\n";
    open(OUT, '>fetch.sh') or croak "Unable to write command.sh: $!\n";
    print OUT $cmd;
    close(OUT) or croak "Unable to close command.sh: $!\n";
    my @start = <*>;
    system('sh', 'fetch.sh');
    croak "Unable to execute command: $@\n" if $@;
    my @end = <*>;

    if ($#end > $#start + 1) {
        $self->{package}->{build} ||= '.';
    } else {
        my %s = map { $_ => 1 } @start;
        @end = grep { !$s{$_} } @end;
        $self->{package}->{build} = $end[0];
    }

    my @deps = split /\s*,\s*/, ($self->{package}->{data}->{fetch}->{depends} || '');
    foreach my $dep (@deps) {
	my $build;
	
	# -- Build from one of MUD, existing binaries or upstream source...
	#
	if (-f $self->{config}->directory('PACKAGES_DIR') . "/$dep.xml") {
	    print "[Got existing MUD package for $dep]\n";
	    if (!$::OPTS{'depend-nobuild'}) {
		$build = new MUD::Build( package => $dep,
					 config => $self->{config} );
	    }

	} else {
	    system('fakeroot', 'apt-get', '-y', 'install', $dep);
	    next unless $?;
	    my $dpkg = `dpkg -s $dep 2>/dev/null`;
	    print $dpkg;
	    if ($dpkg !~ /Status: install ok installed/) {
		print "+++ Status not installed.\n";
		my $newPkg = new MUD::Package( (%{ $self->{package} }));
		$newPkg->{package} = $dep;
		$newPkg->{data}->{fetch}->{name} = $dep;
		$newPkg->{data}->{deb}->{prefixSection} = 0;
		$build = new MUD::Build( package => $newPkg,
					 config => $self->{config} );
	    }
	}

	# -- If we built, install...
	#
	if ($build) {
	    $build->build();
	    chdir $build->{workdir};
	    system("fakeroot dpkg -i --force-depends *.deb");
	    croak "Unable to install $dep [$?]\n" if $?;
	}
    }
}

