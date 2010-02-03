use warnings;
use strict;
use CGI::Application::Server;
use lib 'lib';
use App::Stinki;
use App::Stinki::Setup;

App::Stinki::Setup::setup_if_needed( dbtype => 'sqlite', dbname => './t/db' );

my $app = App::Stinki->new(PARAMS => {
    cfg_file => './t/stinki.cfg',
});

my $server = CGI::Application::Server->new();
$server->document_root('./t/www');
$server->entry_points({
    '/index.cgi' => $app,
});
$server->run;
