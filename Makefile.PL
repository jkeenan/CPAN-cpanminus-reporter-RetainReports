

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'App::cpanminus::reporter::RetainReports',
    VERSION_FROM => 'lib/App/cpanminus/reporter/RetainReports.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Retain reports on disk rather than transmitting them',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                     'App::cpanminus::reporter' => 0,
                     'CPAN::Testers::Common::Client' => 0,
                     'JSON' => 0,
                     'Test::Reporter' => 0, # do I still need this?
                     'Path::Tiny' => 0.004, # testing
                     'URI' => 0,
                     'CPAN::DistnameInfo' => 0,
                     'Capture::Tiny' => 0,
                    },
);
