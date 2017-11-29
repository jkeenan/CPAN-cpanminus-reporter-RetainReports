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
        test_output   => qr/Building and testing Module-CoreList-3.07/s,
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
          test_output   => qr/Building and testing Catalyst-Runtime-5.90061/s,
    },
} );

done_testing;

##### SUBROUTINES #####

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


sub test_one_log_file {
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

    my $dir = -d 't' ? 't/data' : 'data';
    my $reporter = App::cpanminus::reporter::RetainReports->new(
      force => 1, # ignore mtime check on build.log
      build_logfile => File::Spec->catfile($dir, $args->{build_logfile}),
      'ignore-versions' => 1,
    );
    ok(defined $reporter, 'created new reporter object');

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
        "Got expected start of test output");
}
