#!/usr/bin/perl
#
# Main MUD-Builder script                 (c) Andrew Flegg 2007
#                                         Released under the Artistic Licence
#                                         http://mud-builder.garage.maemo.org/

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use MUD::Config;
use MUD::Build;
use MUD::Package;
use Getopt::Long;

use vars qw(%ACTIONS %OPTS $config);

%ACTIONS = ( build => \&build,
             show  => \&show, );

%OPTS = ();
GetOptions(\%OPTS, 'help',
		   'config=s',
	           'all');

if ($OPTS{help} or !@ARGV) {
    print <<EOM;
MUD-Builder                              (c) Andrew Flegg 2007
~~~~~~~~~~~                              Released under the Artistic Licence
                                         http://mud-builder.garage.maemo.org/
Syntax:
    mud [<options>] <action> [<package> ...]

Options:
    -h, --help                Usage instructions
    -a, --all                 Build all packages ready for upload
    -c, --config=FILE         Use FILE for configuration rather than 'config'

Actions:
    build                     Build the given package(s)
    show                      Show information on the given package(s)

Please contact <andrew\@bleb.org> with any bugs or comments.
EOM
    exit;
}

$config = { base => $Bin };
$config->{file} = $OPTS{config} if $OPTS{config};
$config = new MUD::Config(%$config);

my $action = shift;
if ($OPTS{all}) {
    die "TODO: Not implemented";
} else {
    &{ $ACTIONS{$action}}( $_ ) foreach @ARGV;
}

    
exit;


sub build {
    my ($pkg) = @_;

    print "+++ Trying to build package [$pkg]\n";
    my $builder = new MUD::Build( package => $pkg, config => $config);
    $builder->build();
    $builder->copy();
    $builder->clean();
}

sub show {
    my ($pkg) = @_;

    my $data = new MUD::Package(config => $config)->load( $pkg);
    print Dumper($data);
}
