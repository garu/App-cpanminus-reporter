use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::cpantesters',
    AUTHOR              => 'Breno G. de Oliveira <garu@cpan.org>',
    VERSION_FROM        => 'lib/App/cpantesters.pm',
    ABSTRACT_FROM       => 'lib/App/cpantesters.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'                    => 0,
        'File::Spec'                    => 0,
        'Carp'                          => 0,
        'File::HomeDir'                 => 0,
        'Test::Reporter'                => '1.54',
        'CPAN::Testers::Common::Client' => 0,
        'Parse::CPAN::Meta'             => 0,
        'CPAN::Meta::Converter'         => 0,
        'App::cpanminus'                => 0,
        'Getopt::Long'                  => 0,
        'Pod::Usage'                    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-cpantesters-*' },
);
