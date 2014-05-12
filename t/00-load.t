#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Sport::Orienteering::FYOR' ) || print "Bail out!\n";
}

diag( "Testing Sport::Orienteering::FYOR $Sport::Orienteering::FYOR::VERSION, Perl $], $^X" );
