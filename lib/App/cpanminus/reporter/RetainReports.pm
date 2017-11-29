package App::cpanminus::reporter::RetainReports;
use strict;
use warnings;
use 5.10.1;
use parent ('App::cpanminus::reporter');
our $VERSION = '0.01';
use Carp;
use File::Path qw( make_path );
use File::Spec;
use JSON;
use URI;
use CPAN::DistnameInfo;
#use Data::Dump qw( dd pp );

sub set_report_dir {
    my ($self, $dir) = @_;
    unless (-d $dir) {
        make_path($dir, { mode => 0711 }) or croak "Unable to create $dir";
    }
    $self->{report_dir} = $dir;
}

sub get_report_dir {
    my $self = shift;
    return $self->{report_dir};
}

sub distversion {
  my ($self, $distversion) = @_;
  $self->{_distversion} = $distversion if $distversion;
  return $self->{_distversion};
}

sub distname {
  my ($self, $distname) = @_;
  $self->{_distname} = $distname if $distname;
  return $self->{_distname};
}

sub parse_uri {
  my ($self, $resource) = @_;

  my $d = CPAN::DistnameInfo->new($resource);
  $self->distversion($d->version);
  $self->distname($d->dist);

  my $uri = URI->new( $resource );
  my $scheme = lc $uri->scheme;
  if (    $scheme ne 'http'
      and $scheme ne 'https'
      and $scheme ne 'ftp'
      and $scheme ne 'cpan'
  ) {
    print "invalid scheme '$scheme' for resource '$resource'. Skipping...\n"
      unless $self->quiet;
    return;
  }

  my $author = $self->get_author( $uri->path );
  unless ($author) {
    print "error fetching author for resource '$resource'. Skipping...\n"
      unless $self->quiet;
    return;
  }

  # the 'LOCAL' user is reserved and should never send reports.
  if ($author eq 'LOCAL') {
    print "'LOCAL' user is reserved. Skipping resource '$resource'\n"
      unless $self->quiet;
    return;
  }

  $self->author($author);

  $self->distfile(substr("$uri", index("$uri", $author)));

  return 1;
}

sub make_report {
    my ($self, $resource, $dist, $result, @test_output) = @_;

    if ( index($dist, 'Local-') == 0 ) {
        print "'Local::' namespace is reserved. Skipping resource '$resource'\n"
          unless $self->quiet;
        return;
    }
    return unless $self->parse_uri($resource);

    my $author = $self->author;

    my $cpanm_version = $self->{_cpanminus_version} || 'unknown cpanm version';
    my $meta = $self->get_meta_for( $dist );
    my %CTCC_args = (
        author      => $self->author,
        distname    => $dist,   # string like: Mason-Tidy-2.57
        grade       => $result,
        via         => "App::cpanminus::reporter $App::cpanminus::reporter::VERSION ($cpanm_version)",
        test_output => join( '', @test_output ),
        prereqs     => ($meta && ref $meta) ? $meta->{prereqs} : undef,
    );
    my $tdir = $self->get_report_dir();
    croak "Could not locate $tdir" unless (-d $tdir);
    my $report = File::Spec->catfile($tdir, join('.' => $self->author, $dist, 'log', 'json'));
    open my $OUT, '>', $report or croak "Unable to open $report for writing";
    say $OUT encode_json( {
        %CTCC_args,
        'distversion' => $self->distversion,
        'dist'        => $self->distname,   # string like: Mason-Tidy
    } );
    close $OUT or croak "Unable to close $report after writing";

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

