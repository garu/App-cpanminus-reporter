use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::cpanminus::reporter',
    AUTHOR              => 'Breno G. de Oliveira <garu@cpan.org>',
    VERSION_FROM        => 'lib/App/cpanminus/reporter.pm',
    ABSTRACT_FROM       => 'lib/App/cpanminus/reporter.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'                    => 0,
        'File::Spec'                    => 3.19,
        'Carp'                          => 0,
        'File::HomeDir'                 => 0.58,
        'Test::Reporter'                => '1.54',
        'CPAN::Testers::Common::Client' => 0,
        'Parse::CPAN::Meta'             => 0,
        'CPAN::Meta::Converter'         => 0,
        'Getopt::Long'                  => 0,
        'Pod::Usage'                    => 0,
        'Try::Tiny'                     => 0,
        'Metabase::Resource'            => 0,
        'Config::Tiny'                  => 2.08,
    },
    EXE_FILES => [ 'bin/cpanm-reporter' ],
    dist      => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean     => { FILES => 'App-cpanminus-reporter-*' },
);
