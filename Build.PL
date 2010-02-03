use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::Stinki',
    license             => 'perl',
    dist_author         => 'Jaldhar H. Vyas <jaldhar@braincells.com>',
    dist_version_from   => 'lib/App/Stinki.pm',
    tmpl_files          => eval {
        my %tmpls; File::Find::find(
            {
                wanted => sub {
                    if ( -f $_ ) {
                        $tmpls{$File::Find::name} = $File::Find::name;
                    }
                },
            },
            'lib/App/Stinki/templates',
        );
        return \%tmpls;
    },
    build_requires => {
        'File::Find'                    => 0,      
        'Test::More'                    => 0,
        'Test::WWW::Mechanize::CGIApp'  => 0,
    },
    requires => {
        'Class::Delegator'              => 0,
        'Module::Load'                  => 0,
        'Titanium'                      => 0,
        'URI::Escape'                   => 0,
        'Wiki::Toolkit'                 => 0,
    },
    meta_merge => {
        resources => {
            repository  => 'http://github.com/jaldhar/App-Stinki',
        },
    },
    add_to_cleanup      => [ 'App-Stinki-*' ],
    create_makefile_pl  => 'traditional',
    sign                => 1,
);

$builder->add_build_element('tmpl');
$builder->create_build_script();

