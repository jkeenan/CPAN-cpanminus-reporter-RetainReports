package App::cpanminus::reporter::RetainReports;
use strict;
use parent ('App::cpanminus::reporter');
our $VERSION = '0.01';
use CPAN::Testers::Common::Client;
use Test::Reporter;
use Carp;
use Data::Dump qw( dd pp );

sub run {
  my $self = shift;
  return unless ($self->_check_cpantesters_config_data and $self->_check_build_log);

  my $logfile = $self->build_logfile;
  open my $fh, '<', $logfile
    or Carp::croak "error opening build log file '$logfile' for reading: $!";

  my $header = <$fh>;
  if ($header =~ /^cpanm \(App::cpanminus\) (\d+\.\d+) on perl (\d+\.\d+)/) {
    $self->{_cpanminus_version} = $1;
    $self->{_perl_version} = $2;
  }
  else {
      Carp::croak(
          'Unable to find cpanminus/perl versions on build.log. '
        . 'Please update App::cpanminus. If you think this is a mistake, '
        . 'please send us a bug report with your version of App::cpanminus, '
        . 'App::cpanminus::reporter, perl -V and your failing build.log file.'
      );
  }

  my $found = 0;
  my $parser;

  # we could go over 100 levels deep on the dependency track
  no warnings 'recursion';
  $parser = sub {
    my ($dist, $resource) = @_;
    (my $dist_vstring = $dist) =~ s/\-(\d+(?:\.\d)+)$/-v$1/ if $dist;
    my @test_output = ();
    my $recording;
    my $has_tests = 0;
    my $found_na;
    my $fetched;

    while (<$fh>) {
      if ( /^Fetching (\S+)/ ) {
        next if /CHECKSUMS$/;
        $fetched = $1;
        $resource = $fetched unless $resource;
      }
      elsif ( /^Entering (\S+)/ ) {
        my $dep = $1;
        $found = 1;
        if ($recording && $recording eq 'test') {
            Carp::croak 'Parsing error. This should not happen. Please send us a report!';
        }
        else {
            print "entering $dep, " . ($fetched || '(local)') . "\n" if $self->verbose;
            $parser->($dep, $fetched);
            print "left $dep, " . ($fetched || '(local)') . "\n" if $self->verbose;
            next;
        }
      }
      elsif ( /^Running (?:Build|Makefile)\.PL/ ) {
        $recording = 'configure';
      }
      elsif ( $dist and /^Building .*(?:$dist|$dist_vstring)/) {
        print "recording $dist\n" if $self->verbose;
        $has_tests = 1 if /and testing/;
        # if we got here, we need to flush the test output
        # (so far filled with 'configure' output) and start
        # recording the actual tests.
        @test_output = ();
        $recording = 'test';
      }

      push @test_output, $_ if $recording;

      my $result;
      if ($recording) {
        if (   /^Result: (PASS|NA|FAIL|UNKNOWN|NOTESTS)/
           || ($recording eq 'test' && /^-> (FAIL|OK)/)
        ) {
          $result = $1;
          if ($result eq 'FAIL' && $recording eq 'configure') {
            $result = 'NA';
          }
          elsif ($result eq 'OK') {
            $result = $has_tests ? 'PASS' : 'UNKNOWN';
          }
          elsif ($result eq 'NOTESTS') {
              $result = 'UNKNOWN';
          }
        }
        elsif ( $recording eq 'configure' && /^-> N\/A/ ) {
            $found_na = 1;
        }
        elsif (  $recording eq 'configure'
            # https://github.com/miyagawa/cpanminus/blob/devel/lib/App/cpanminus/script.pm#L2269
              && ( /Configure failed for (?:$dist|$dist_vstring)/
                || /proper Makefile.PL\/Build.PL/
                || /configure the distribution/
              )
        ) {
            $result = $found_na ? 'NA' : 'UNKNOWN';
        }
      }
      if ($result) {
        my $dist_without_version = $dist;
        $dist_without_version =~ s/(\S+)-[\d.]+$/$1/;

        if (@test_output <= 2) {
            print "No test output found for '$dist'. Skipping...\n"
                . "To send test reports, please make sure *NOT* to pass '-v' to cpanm or your build.log will contain no output to send.\n";
        }
        elsif (!$resource) {
            print "Skipping report for local installation of '$dist'.\n";
        }
        elsif ( defined $self->exclude && exists $self->exclude->{$dist_without_version} ) {
            print "Skipping $dist as it's in the 'exclude' list...\n" if $self->verbose;
        }
        elsif ( defined $self->only && !exists $self->only->{$dist_without_version} ) {
            print "Skipping $dist as it isn't in the 'only' list...\n" if $self->verbose;
        }
        elsif ( !$self->ignore_versions && defined $self->{_perl_version} && ( $self->{_perl_version} ne $] ) ) {
            print "Skipping $dist as its build Perl version ($self->{_perl_version}) differs from the currently running perl ($])...\n" if $self->verbose;
        }
        else {
print STDERR "XXX: Ready to make_report\n";
            my $report = $self->make_report($resource, $dist, $result, @test_output);
        }
        return;
      }
    }
  };

  print "Parsing $logfile...\n" if $self->verbose;
  $parser->();
  print "No reports found.\n" if !$found and $self->verbose;
  print "Finished.\n" if $self->verbose;

  close $fh;
  return;
}

sub make_report {
  my ($self, $resource, $dist, $result, @test_output) = @_;
  #print STDERR "AAA: my own make_report()\n";
#print STDERR "AAA: resource: $resource\n";
#print STDERR "BBB: dist:     $dist\n";
#print STDERR "CCC: result:   $result\n";
#pp(\@test_output);
#print STDERR "DDD:\n";

  if ( index($dist, 'Local-') == 0 ) {
      print "'Local::' namespace is reserved. Skipping resource '$resource'\n"
        unless $self->quiet;
      return;
  }
  return unless $self->parse_uri($resource);

  my $author = $self->author;

  my $cpanm_version = $self->{_cpanminus_version} || 'unknown cpanm version';
  my $meta = $self->get_meta_for( $dist );
  my $client = CPAN::Testers::Common::Client->new(
    author      => $self->author,
    distname    => $dist,
    grade       => $result,
    via         => "App::cpanminus::reporter $App::cpanminus::reporter::VERSION ($cpanm_version)",
    test_output => join( '', @test_output ),
    prereqs     => ($meta && ref $meta) ? $meta->{prereqs} : undef,
  );

  if (!$self->skip_history && $client->is_duplicate) {
      #print STDERR "QQQ: already sent\n";
    print "($resource, $author, $dist, $result) was already sent. Skipping...\n"
      if $self->verbose;
    return;
  }
  else {
      #print STDERR "RRR: NOT already sent\n";
    print "preparing: ($resource, $author, $dist, $result)\n" unless $self->quiet;
  }

  my %test_reporter_args = (
    transport      => $self->config->transport_name,
    transport_args => $self->config->transport_args,
    grade          => $client->grade,
    distribution   => $dist,
    distfile       => $self->distfile,
    from           => $self->config->email_from,
    comments       => $client->email,
    via            => $client->via,
  );
  $self->{test_reporter_args} = \%test_reporter_args;
  return;
}

sub get_test_reporter_args {
    my $self = shift;
    return $self->{test_reporter_args} if exists $self->{test_reporter_args};
    return;
}

=head1 NAME

App::cpanminus::reporter::RetainReports - Retain reports on disk rather than transmitting them

=head1 SYNOPSIS

    use App::cpanminus::reporter::RetainReports;

=head1 DESCRIPTION

=head2 Rationale:  Who Should Use This Library?

This library is a subclass of Breno G. de Oliveira's CPAN library
L<App-cpanminus-reporter|http://search.cpan.org/~garu/App-cpanminus-reporter-0.17/>.
That library provides the utility program F<cpanm-reporter|http://search.cpan.org/dist/App-cpanminus-reporter-0.17/bin/cpanm-reporter> a way to generate and transmit CPANtesters reports after
using Tatsuhiko Miyagawa's
L<cpanm|http://search.cpan.org/~miyagawa/App-cpanminus-1.7043/bin/cpanm>
utility to install libraries from CPAN.

Like similar test reporting methodologies, F<App-cpanminus-reporter> does not
retain test reports on disk once they have been transmitted to
L<CPANtesters|http://www.cpantesters.org>.  Whether a particular module passed
or failed its tests is very quickly reported to
L<http://fast-matrix.cpantesters.org/> and, after a lag, the complete report
is posted to L<http://matrix.cpantesters.org/>.  That works fine under normal
circumstances, but if there are any technical problems with those websites the
person who ran the tests originally has no easy access to reports --
particularly to reports of failures.  Quick access to reports of test failures
is particularly valuable when testing a library against specific commits to
the Perl 5 core distribution and against Perl's monthly development releases.

This library is intended to provide at least a partial solution to that
problem.  It is intended for use by at least three different kinds of users:

=over 4

=item * People working on the Perl 5 core distribution or the Perl toolchain

These individuals (commonly known as the Perl 5 Porters (P5P) and the Perl
Toolchain Gang) often want to know the impact on the most commonly used CPAN
libraries of (a) a particular commit to Perl 5's master development branch
(known as I<blead>) or some other branch in the repository; or (b) a monthly
development release of F<perl> (5.27.1, 5.27.2, etc.).  After installing
blead, a branch or a monthly dev release, they often want to install hundreds
of modules at a time and inspect the results for breakage.

=item * CPAN library authors and maintainers

A diligent CPAN maintainer pays attention to whether her libraries are
building and testing properly against Perl 5 blead.  Such a maintainer can use
this library to get reports more quickly than waiting upon CPANtesters.

=item * People maintaining lists of CPAN libraries which they customarily install with F<perl>

Organizations which use many CPAN libraries in their production tend to keep a
curated list of them, often in a format like
L<cpanfile|http://search.cpan.org/~miyagawa/Module-CPANfile-1.1002/lib/cpanfile.pod>.
Those organizations can use this library to assess the impact of changes in
blead or a branch or of a monthly dev release on such a list.

=back

=head1 USAGE



=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

    James E Keenan
    CPAN ID: JKEENAN
    jkeenan@cpan.org
    http://thenceforward.net/perl

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).  cpanm(1).  cpanm-reporter(1).  App::cpanminus::reporter(3).

=cut

1;

