# -*- perl -*-
use strict;
use warnings;
use Test::More;
use Carp;
use Data::Dump qw( dd pp );
use File::Spec;
use File::Temp qw( tempdir );
use Path::Tiny ();
use JSON;
use Capture::Tiny qw( capture_stdout );

BEGIN { use_ok( 'App::cpanminus::reporter::RetainReports' ); }

{
    my $reporter = App::cpanminus::reporter::RetainReports->new(verbose => 1);
    ok(defined $reporter, "Inherited constructor returned defined object");
    isa_ok($reporter, 'App::cpanminus::reporter::RetainReports');
    can_ok('App::cpanminus::reporter::RetainReports', qw|
        run
        make_report
    | );
}

test_one_log_file( {
    build_logfile   => 'build.single.log',
    json_title      => 'BINGOS.Module-CoreList-3.07',
    expected        =>  {
        author        => 'BINGOS',
        distname      => 'Module-CoreList-3.07',
        dist          => 'Module-CoreList',
        distversion   => '3.07',
        grade         => 'PASS',
        test_output   => qr/Building and testing Module-CoreList-3\.07/s,
    },
} );

test_one_log_file( {
    build_logfile   => 'build.single_extended.log',
    json_title      => 'JJNAPIORK.Catalyst-Runtime-5.90061',
    expected        =>  {
          author        => 'JJNAPIORK',
          distname      => 'Catalyst-Runtime-5.90061',
          dist          => 'Catalyst-Runtime',
          distversion   => '5.90061',
          grade         => 'PASS',
          test_output   => qr/Building and testing Catalyst-Runtime-5\.90061/s,
    },
} );

test_one_log_file( {
    build_logfile   => 'build.configure_failed.log',
    json_title      => 'BOBW.X86-Udis86-1.7.2.3',
    expected        =>  {
          author        => 'BOBW',
          distname      => 'X86-Udis86-1.7.2.3',
          dist          => 'X86-Udis86',
          distversion   => '1.7.2.3',
          # App::cpanminus::reporter::run sets grade to NA when failure is in
          # configure stage
          grade         => 'NA',
          test_output   => qr/FAIL Configure failed for X86-Udis86-v1\.7\.2\.3/s,
    },
} );

test_one_log_file( {
    build_logfile   => 'build.version_strings.log',
    json_title      => 'BOBW.X86-Udis86-1.7.2.3',
    expected        =>  {
          author        => 'BOBW',
          distname      => 'X86-Udis86-1.7.2.3',
          dist          => 'X86-Udis86',
          distversion   => '1.7.2.3',
          grade         => 'FAIL',
          test_output   => qr/Building and testing X86-Udis86-v1\.7\.2\.3/s,
    },
} );

test_one_log_file( {
    build_logfile   => 'build.module_dir.log',
    # Note the 'v' in 4 values
    json_title      => 'AMBS.Lingua-NATools-v0.7.8',
    expected        =>  {
          author        => 'AMBS',
          distname      => 'Lingua-NATools-v0.7.8',
          dist          => 'Lingua-NATools',
          distversion   => 'v0.7.8',
          grade         => 'PASS',
          test_output   => qr/Building and testing Lingua-NATools-v0\.7\.8/s,
    },
} );

test_no_test_output( {
    build_logfile   => 'build.verbose_cpanm.log',
    json_title      => 'SRI.Mojolicious-4.89',
    expected        =>  {
          author        => 'SRI',
          distname      => 'Mojolicious-4.89',
          dist          => 'Mojolicious',
          distversion   => '4.89',
          grade         => '',
          test_output   => '',
    },
} );

done_testing;

######################### SUBROUTINES #########################

=pod

    test_one_log_file( {
        build_logfile   => 'build.single.log',
        json_title      => 'BINGOS.Module-CoreList-3.07',
        expected        =>  {
            author        => 'BINGOS',
            distname      => 'Module-CoreList-3.07',
            dist          => 'Module-CoreList',
            distversion   => '3.07',
            grade         => 'PASS',
            test_output   => qr/Building and testing Module-CoreList-3.07/s,
        },
    } );

=cut 

sub _check_args {
    my $args = shift;
    croak "Must pass hashref to test_one_log_file()"
        unless ref($args) eq 'HASH';
    for my $k (qw| build_logfile json_title expected |) {
        croak "Must provide value for element '$k'"
            unless exists $args->{$k};
    }
    for my $l (qw| author distname dist distversion grade test_output | ) {
        croak "Must provide value for element '$l' in 'expected'"
            unless exists $args->{expected}->{$l};
    }
    return 1;
}

sub _create_reporter {
    my $args = shift;
    my $dir = -d 't' ? 't/data' : 'data';
    my $reporter = App::cpanminus::reporter::RetainReports->new(
        force => 1, # ignore mtime check on build.log
        build_logfile => File::Spec->catfile($dir, $args->{build_logfile}),
        'ignore-versions' => 1,
    );
    ok(defined $reporter, 'created new reporter object');
    return $reporter;
}

sub test_one_log_file {
    my $args = shift;
    _check_args($args);
    my $reporter = _create_reporter($args);

    {
        no warnings 'redefine';
        local *App::cpanminus::reporter::RetainReports::_check_cpantesters_config_data = sub { 1 };
        my $tdir = tempdir( CLEANUP => 1 );
        $reporter->set_report_dir($tdir);
        $reporter->run;
        my $lfile = File::Spec->catfile($tdir, "$args->{json_title}.log.json");
        ok(-f $lfile, "Log file $lfile created");
        my $f = Path::Tiny::path($lfile);
        my $decoded = decode_json($f->slurp_utf8);
        test_json_output($decoded, $args->{expected});
    };
}

sub test_no_test_output {
    my $args = shift;
    _check_args($args);
    my $reporter = _create_reporter($args);

    {
        no warnings 'redefine';
        local *App::cpanminus::reporter::RetainReports::_check_cpantesters_config_data = sub { 1 };
        my $tdir = tempdir( CLEANUP => 1 );
        $reporter->set_report_dir($tdir);
        my $output = capture_stdout { $reporter->run; };
        like($output, qr/No test output found for '$args->{expected}->{distname}'/s,
            "Got expected output indicating no test output for $args->{expected}->{distname}");
    };
}

sub test_json_output {
    my ($got, $expected) = @_;
    my $pattern = "%-28s%s";
    is($got->{author}, $expected->{author},
        sprintf($pattern => ('Got expected author:', $expected->{author})));
    is($got->{distname}, $expected->{distname},
        sprintf($pattern => ('Got expected distname:', $expected->{distname})));
    is($got->{dist}, $expected->{dist},
        sprintf($pattern => ('Got expected dist:', $expected->{dist})));
    is($got->{distversion}, $expected->{distversion},
        sprintf($pattern => ('Got expected distversion:', $expected->{distversion})));
    is($got->{grade}, $expected->{grade},
        sprintf($pattern => ('Got expected grade:', $expected->{grade})));
    like($got->{test_output}, $expected->{test_output},
        "Got expected test output");
}
