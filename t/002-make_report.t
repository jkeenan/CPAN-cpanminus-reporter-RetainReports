# -*- perl -*-
use strict;
use warnings;
use Test::More;
use Data::Dump qw( dd pp );

BEGIN { use_ok( 'App::cpanminus::reporter::RetainReports' ); }

{
    my $reporter = App::cpanminus::reporter::RetainReports->new(verbose => 1);
    ok(defined $reporter, "Inherited constructor returned defined object");
    isa_ok($reporter, 'App::cpanminus::reporter::RetainReports');
    can_ok('App::cpanminus::reporter::RetainReports', qw|
        run
        make_report
        get_test_reporter_args
    | );
}

{
    my $dir = -d 't' ? 't/data' : 'data';
    my $reporter = App::cpanminus::reporter::RetainReports->new(
      force => 1, # ignore mtime check on build.log
      build_logfile => $dir . '/build.single.log', 
      'ignore-versions' => 1,
      verbose => 1,
    ), 'created new reporter object';
    ok(defined $reporter, 'created new reporter object');

    # PROBLEM:  In parent, make_report() is only called within the definition
    # of a coderef which in turn is only called within run().  Using
    # test_make_report() to mock make_report() rewrites that (internal) method
    # so as to sidestep what we really want to test, namely, that we can store
    # the test output, the Test::Reporter arguments, etc.

    # Would the alternative be to test make_report() directly -- even though
    # it's not called in production as such? To do so, we'd need to know
    # the content of $resource, $dist, $result and @test_output.

    sub test_make_report {
      my ($self, $resource, $dist, $result, @test_output) = @_;
      is $reporter, $self, 'got the reporter object';
      is $resource, 'http://www.cpan.org/authors/id/B/BI/BINGOS/Module-CoreList-3.07.tar.gz'
         => 'resource is properly set';

      is $dist, 'Module-CoreList-3.07' => 'dist is properly set';
      is $result, 'PASS' => 'result is properly set';

      is $test_output[0], "Building and testing Module-CoreList-3.07\n"
         => 'test output starts ok';

      is $test_output[-1], "Result: PASS\n" => 'test output finishes ok';
pp(\@test_output);
pass($0);
    }

    {
      no warnings 'redefine';
      local *App::cpanminus::reporter::RetainReports::_check_cpantesters_config_data = sub { 1 };
      local *App::cpanminus::reporter::RetainReports::make_report = \&test_make_report;
      $reporter->run;
      # Below won't work if we're mocking:
      my $test_reporter_args = $reporter->get_test_reporter_args();
pp($test_reporter_args);
pass($0);
    };
}

done_testing;

