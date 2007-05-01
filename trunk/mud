#!/usr/bin/perl
#
# Main MUD-Builder script                 (c) Andrew Flegg 2007
#                                         Released under the Artistic Licence
#                                         http://mud-builder.garage.maemo.org/

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Carp;
use MUD::Config;
use MUD::Build;
use MUD::Package;
use Getopt::Long;
use File::Basename;
use Data::Dumper;

use vars qw(%ACTIONS %OPTS $config);

%ACTIONS = map { $_ => 1 } qw( build get compile clean diff show );
%OPTS = ();
GetOptions(\%OPTS, 'help',
		   'config=s',
	           'all');

if ($OPTS{help} or !@ARGV or !$ACTIONS{$ARGV[0]}) {
    print <<EOM;
MUD-Builder                              (c) Andrew Flegg 2007
~~~~~~~~~~~                              Released under the Artistic Licence
                                         http://mud-builder.garage.maemo.org/
Syntax:
    mud [<options>] <action> [<package> ...]

Options:
    -h, --help                Usage instructions
    -a, --all                 Run <action> on all packages
    -c, --config=FILE         Use FILE for configuration rather than 'config'

Actions:
    build                     Build the given package(s) from upstream
    show                      Show information on the given package(s)

    get                       Fetch and unpack the source in <build_dir>
    compile                   Build from previously downloaded source
    diff                      Save a diff from upstream to current source
    clean                     Remove downloaded source

Please contact <andrew\@bleb.org> with any bugs or comments.
EOM
    exit;
}

$config = { base => $Bin };
$config->{file} = $OPTS{config} if $OPTS{config};
$config = new MUD::Config(%$config);

my $action = shift;
my @pkgs   = @ARGV;
if ($OPTS{all}) {
    opendir(DIR, $config->directory('PACKAGES_DIR')) or die "Can't read packages dir: $!\n";
    @pkgs = map { s/\.xml$//; $_ } grep { /\.xml$/ } readdir(DIR);
    closedir(DIR);
}

# Keep track of which packages are built in this specific command
%::built = ();

foreach my $n (@pkgs) {
    $n = basename($n, ".xml") if -f $n;
    eval("print \&$action(\$n)");
    croak "Failed to run $action on $n: $@\n" if $@;
}

if ($action eq "build") {
# Clean packages which were built
    foreach my $n (@pkgs) {
	clean($n);
    }
}

    
exit;


sub get {
    my ($pkg) = @_;

    my $builder = new MUD::Build( package => $pkg, config => $config);
    $builder->fetch();

    print "+++ Workdir = [".$builder->{workdir}."]\n";
    print "+++ Build dir = [".$builder->{data}->{build}."]\n";
    chdir $builder->{workdir};
    my $repo = $builder->{workdir}.'/.orig';
    my $base = basename($builder->{data}->{build});
    print "Creating Subversion repository... ";
    system('svnadmin', 'create', $repo);
    print "done.\nImporting upstream source... ";
    system('svn', 'import', '-q', '-m', 'Import', $base, "file://$repo");
    print "done.\nRemoving temporary directory... ";
    system('rm', '-rf', $base);
    print "done.\nChecking out working copy... ";
    system('svn', 'co', '-q', "file://$repo", $base);
    print "done.\nRemoving repository... ";
    system('rm', '-rf', $repo);
    print "done.\n";

    $builder->patch();
    chdir $builder->{data}->{build} || croak "Build dir not set.\n";
    my @toAdd = map { /^\s*\?\s*(.*?)[\s\r\n]*$/ } `svn status`;
    system('svn', 'add', '-q', @toAdd) if @toAdd;

    print "\n\n--- $pkg can now be compiled and tested in:\n       $builder->{data}->{build}\n";
}

sub compile {
    my ($pkg) = @_;

    my $builder = new MUD::Build( package => $pkg, config => $config );
    croak "No available source, use <get>\n" unless $builder->{data}->{build};

    $builder->compile();
    $builder->copy();
}


sub diff {
    my ($pkg) = @_;

    my $builder = new MUD::Build( package => $pkg, config => $config );
    croak "No available source, use <get>\n" unless $builder->{data}->{build};

    chdir $builder->{data}->{build};
    my $patch = $config->directory('PACKAGES_DIR')."/patch/$pkg.patch";
    my $count = 0;

    croak("Cannot fork: $!") unless defined(my $pid = open(EXC, "-|"));
    exec('svn diff') unless $pid;
    open(OUT, ">$patch") or croak "Unable to open [$patch]: $!\n";
    while(<EXC>) { print OUT $_; $count++; }
    close(OUT) or croak "Unable to close [$patch]: $!\n";
    close(EXC);

    if ($count) {
        print "+++ Patch generated in [$patch]\n";
    } else {
        unlink $patch;
        print "+++ No patch against upstream necessary.\n";
    }
}
 

sub clean {
    my ($pkg) = @_;

    my $builder = new MUD::Build( package => $pkg, config => $config);
    $builder->clean();
}


sub build {
    my ($pkg) = @_;

    print "+++ Trying to build package [$pkg]\n";
    my $builder = new MUD::Build( package => $pkg, config => $config);
    $builder->build();
    $builder->copy();
#    $builder->clean();
}

sub show {
    my ($pkg) = @_;

    my $data = new MUD::Package(config => $config)->load( $pkg);
    print Dumper($data);
}
