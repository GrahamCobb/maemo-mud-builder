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
    foreach my $d (@deps) {
	my $builder = new MUD::Build(package => $d, config => $self->{config});
	$builder->build();
        chdir $builder->{workdir};
	system("fakeroot dpkg -i --force-depends *.deb");
        croak "Unable to install $d [$?]\n" if $?;
    }
}

