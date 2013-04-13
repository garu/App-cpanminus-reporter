package App::cpanminus::reporter;

use warnings;
use strict;

our $VERSION = '0.01';

use Carp ();
use File::Spec     3.19;
use File::HomeDir  0.58 ();
use Test::Reporter 1.54;
use CPAN::Testers::Common::Client;
use Parse::CPAN::Meta;
use CPAN::Meta::Converter;
use Try::Tiny;
use URI;
use Metabase::Resource;

# TODO:
## BEGIN: factor these into CPAN::Testers::Common::Client?
use Config::Tiny 2.08 ();

## stolen verbatim from CPAN::Reporter::Config
sub _get_config_dir {
    if ( defined $ENV{PERL_CPAN_REPORTER_DIR} &&
         length  $ENV{PERL_CPAN_REPORTER_DIR}
    ) {
        return $ENV{PERL_CPAN_REPORTER_DIR};
    }

    my $conf_dir = File::Spec->catdir(File::HomeDir->my_home, ".cpanreporter");

    if ($^O eq 'MSWin32') {
      my $alt_dir = File::Spec->catdir(File::HomeDir->my_documents, ".cpanreporter");
      $conf_dir = $alt_dir if -d $alt_dir && ! -d $conf_dir;
    }

    return $conf_dir;
}

## stolen verbatim from CPAN::Reporter::Config
sub _get_config_file {
    if (  defined $ENV{PERL_CPAN_REPORTER_CONFIG} &&
          length  $ENV{PERL_CPAN_REPORTER_CONFIG}
    ) {
        return $ENV{PERL_CPAN_REPORTER_CONFIG};
    }
    else {
        return File::Spec->catdir( _get_config_dir, 'config.ini' );
    }
}
## END: factor these into CPAN::Testers::Common::Client?


sub new {
  my ($class, %params) = @_;
  my $self = bless {}, $class;
  my $config_filename = _get_config_file();
  my $config = Config::Tiny->read( $config_filename );
  # FIXME: poor man's validation, we should factor this out
  # from CPAN::Reporter::Config SOON!
  unless ($config) {
      warn "Error reading configuration file '$config_filename': "
         . Config::Tiny->errstr() . "\nFalling back to default values\n";

      $config = {
          _ => {
              edit_report => 'default:no pass/na:no',
              email_from  => getpwuid($<) . '@localhost',
              send_report => 'default:yes pass/na:yes',
              transport   => 'Metabase uri https://metabase.cpantesters.org/api/v1/ id_file ' . File::Spec->catdir( _get_config_dir, 'metabase_id.json' ),
          },
      };
  }
  my @transport = split /\s+/ => $config->{_}{transport};
  my $transport_name = shift @transport
    or die 'transport method missing.';
  $config->{_}{transport} = {
      name => $transport_name,
      args => [ @transport ],
  };
  $config->{_}{email_from} = $params{email_from} if exists $params{email_from};
  $self->config( $config->{_} );

  $self->build_dir(
          $params{build_dir}
       || File::Spec->catdir( File::HomeDir->my_home, '.cpanm', 'latest-build' )
  );

  $self->build_logfile(
          $params{build_logfile}
      ||  File::Spec->catfile( $self->build_dir, 'build.log' )
  );

  return $self;
}


## basic accessors ##

sub config {
    my ($self, $config) = @_;
    $self->{_config} = $config if $config;
    return $self->{_config};
}

sub build_dir {
  my ($self, $dir) = @_;
  $self->{_build_dir} = $dir if $dir;
  return $self->{_build_dir};
}

sub build_logfile {
  my ($self, $file) = @_;
  $self->{_build_logfile} = $file if $file;
  return $self->{_build_logfile};
}


sub run {
  my $self = shift;

  my $logfile = $self->build_logfile;
  open my $fh, '<', $logfile
    or Carp::croak "error opening build log file '$logfile' for reading: $!";

  my $parser;

  $parser = sub {
    my ($dist, $resource) = @_;
    my @test_output = ();
    my $recording = 0;
    my $str = '';
    my $fetched;

    while (<$fh>) {
        if ( /^Fetching (\S+)/ ) {
            $fetched = $1;
            $resource = $fetched unless $resource;
        }
        elsif ( /^Entering (\S+)/ ) {
            my $dep = $1;
            Carp::croak 'Parsing error. This should not happen. Please send us a report!' if $recording;
            Carp::croak "Parsing error. Found '$dep' without fetching first." unless $resource;
            print "entering $dep, $fetched\n";
            $parser->($dep, $fetched);
            print "left $dep, $fetched\n";
            next;
        }
        elsif ( $dist and /^Building and testing $dist/) {
            print "recording $dist\n";
            $recording = 1;
        }

        push @test_output, $_ if $recording;
       
        if ( $recording and ( /^Result: (PASS|NA|FAIL|UNKNOWN)/ or /^-> (FAIL|OK)/ ) ) {
            my $result = $1;
            $result = 'PASS' if $result eq 'OK';
            if (@test_output <= 2) {
                print "No test output found for '$dist'. Skipping...\n"
                    . "To send test reports, please make sure *NOT* to pass '-v' to cpanm or your build.log will contain no output to send.\n";
            }
            else {
                my $report = $self->make_report($resource, $dist, $result, @test_output);
            }
            return;
        }
    }
  };

  $parser->();

  close $fh;
  return;
}

sub get_author {
  my ($self, $path ) = @_;
  my $metadata;

  try {
    $metadata = Metabase::Resource->new( q[cpan:///distfile/] . $path )->metadata;
  }
  catch {
    print "DEBUG: $_";
  };
  return unless $metadata;

  return $metadata->{cpan_id};
}


sub make_report {
    my ($self, $resource, $dist, $result, @test_output) = @_;

    my $uri = URI->new( $resource );
    my $scheme = lc $uri->scheme;
    if ($scheme ne 'http' and $scheme ne 'ftp' and $scheme ne 'cpan') {
        print "invalid scheme '$scheme' for resource '$resource'. Skipping...\n";
        return;
    }

    my $author = $self->get_author( $uri->path );
    unless ($author) {
        print "error fetching author for resource '$resource'. Skipping...\n";
        return;
    }

    eval { require App::cpanminus };
    my $cpanm = $@ ? 'unknown cpanm' : "cpanm $App::cpanminus::VERSION";

    print "sending: ($resource, $author, $dist, $result)\n";

    my $meta = $self->get_meta_for( $dist );
    my $client = CPAN::Testers::Common::Client->new(
          author      => $author,
          distname    => $dist,
          grade       => $result,
          via         => "App::cpanminus::reporter $VERSION ($cpanm)",
          test_output => join( '', @test_output ),
          prereqs     => ($meta && ref $meta) ? $meta->{prereqs} : undef,
    );

    my $reporter = Test::Reporter->new(
        transport      => $self->config->{transport}{name},
        transport_args => $self->config->{transport}{args},
        grade          => $client->grade,
        distribution   => $dist,
        distfile       => ($uri->path_segments)[-1],
        from           => $self->config->{email_from},
        comments       => $client->email,
        via            => $client->via,
    );
    $reporter->send() || die $reporter->errstr();
}

sub get_meta_for {
    my ($self, $dist) = @_;
    my $distdir = File::Spec->catdir( $self->build_dir, $dist );

    foreach my $meta_file ( qw( META.json META.yml META.yaml ) ) {
        my $meta_path = File::Spec->catfile( $distdir, $meta_file );
        if (-e $meta_path) {
            my $meta = eval { Parse::CPAN::Meta->load_file( $meta_path ) };
            next if $@;

            if (!$meta->{'meta-spec'} or $meta->{'meta-spec'}{version} < 2) {
                $meta = CPAN::Meta::Converter->new( $meta )->convert( version => 2 );
            }
            return $meta;
        }
    }
    return;
}


42;
__END__

=head1 NAME

App::cpanminus::reporter - [One line description of module's purpose here]


=head1 SYNOPSIS

    use App::cpanminus::reporter;

  
=head1 DESCRIPTION


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=over 4

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
App::cpanminus::reporter requires no configuration files or environment variables.


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-app-cpanminus-reporter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Breno G. de Oliveira  C<< <garu@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, Breno G. de Oliveira C<< <garu@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
