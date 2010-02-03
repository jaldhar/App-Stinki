#!perl

use strict;
use warnings;
use Test::More tests => 1;
use Test::WWW::Mechanize::CGIApp;
use App::Stinki;
use App::Stinki::Setup;

if (! -f './t/db') {
    App::Stinki::Setup::setup( 
        dbtype => 'sqlite', dbname => './t/db'
    );
}

my $mech = Test::WWW::Mechanize::CGIApp->new;

$mech->app('App::Stinki');

$mech->app(
    sub {
        my $app = App::Stinki->new(PARAMS => {
            cfg_file => './t/stinki.cfg',
        });
        $app->run();
    }
);

$mech->get_ok(q{/});

END {
    if ( -f './t/db') {
        unlink './t/db';
    }
}

