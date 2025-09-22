# -*- perl -*-
use strict;
use warnings;
use Cwd;
use Test::More;
use File::Spec;
use File::Temp ( qw| tempdir | );

BEGIN { use_ok( 'CPAN::cpanminus::reporter::RetainReports' ); }

{
    note("Testing 'file' scheme");

    my $reporter = CPAN::cpanminus::reporter::RetainReports->new(verbose => 1);
    ok(defined $reporter, "Inherited constructor returned defined object");
    isa_ok($reporter, 'CPAN::cpanminus::reporter::RetainReports');

    my ($uri, $rf);
    my $cwd = cwd();
    my $author = 'METATEST';
    my $first_id =  substr($author, 0, 1);
    my $second_id = substr($author, 0, 2);
    my $distro = 'Phony-PASS';
    my $distro_version = '0.01';
    my $tarball = "${distro}-${distro_version}.tar.gz";
    my $tarball_for_testing = File::Spec->catfile($cwd, 't', 'data',
        $first_id, $second_id, $author, $tarball);
    ok(-f $tarball_for_testing, "Located tarball '$tarball_for_testing'");
    $uri = qq|file://$tarball_for_testing|;
    $rf = $reporter->parse_uri($uri);
    ok($rf, "parse_uri() returned true value");
    my %expect = (
        distname => $distro,
        distversion => $distro_version,
        distfile => File::Spec->catfile($author, $tarball),
        author => $author,
    );
    is($reporter->distname(), $expect{distname},
        "distname() returned expected value: $expect{distname}");
    is($reporter->distversion(), $expect{distversion},
        "distversion() returned expected value: $expect{distversion}");
    is($reporter->distfile(), $expect{distfile},
        "distfile() returned expected value: $expect{distfile}");
    ok( defined $reporter->author(),
        "author() returned defined value, as expected");
    is($reporter->author(), $expect{author},
        "author() returned expected value: $expect{author}");
}

done_testing;
