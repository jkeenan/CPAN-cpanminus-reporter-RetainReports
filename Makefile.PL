use ExtUtils::MakeMaker;
require 5.008;
if ($^O =~ /^MSWin32$/i ) {
    die ('OS unsupported');
}

my $mm_ver = ExtUtils::MakeMaker->VERSION;

WriteMakefile(
    NAME         => 'CPAN::cpanminus::reporter::RetainReports',
    VERSION_FROM => 'lib/CPAN/cpanminus/reporter/RetainReports.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Retain reports on disk rather than transmitting them',
    EXE_FILES    => [ 'scripts/dump-parsed-cpanm-build-logs' ],
    PREREQ_PM    => {
                     'App::cpanminus::reporter'         => 0.19,
                     'Carp'                             => 0,
                     'CPAN::Testers::Common::Client'    => 0,
                     'CPAN::DistnameInfo'               => 0,
                     'Cwd'                              => 0,
                     'Data::Dump'                       => 0,   # scripts/dump-parsed-cpanm-build-logs
                     'File::Path'                       => 2.06,
                     'File::Spec'                       => 0,
                     'JSON'                             => 0,
                     'URI'                              => 0,
    },
    ( $mm_ver < 6.63_03 ? 'BUILD_REQUIRES' : 'TEST_REQUIRES' ) =>  {
                     'Test::Simple'                     => 0.44,
                     'Capture::Tiny'                    => 0,
                     'File::Temp'                       => 0,
                     'Path::Tiny'                       => 0,
    },
    ( $mm_ver >= 6.46 ? ( META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository  => {
                url  => 'https://github.com/jkeenan/CPAN-cpanminus-reporter-RetainReports.git',
                web  => 'https://github.com/jkeenan/CPAN-cpanminus-reporter-RetainReports',
                type => 'git',
            },
        },
    }) : () ),
);
