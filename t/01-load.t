#!perl
#
use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use_ok('App::Stinki');
}

diag(
    "Testing App:Stinki $App::Stinki::VERSION, Perl $], $^X"
);
