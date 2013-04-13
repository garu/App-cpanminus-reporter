# TODO - try it with these:
# illguts
# DBIx::Class::Manual::SQLHackers
# TODO - does cpanm work like "cpan ."? This might not have the Fetching/Entering bits
# TODO - get_config_file => Config::Tiny->read( .cpanreporter/config )
use strict;
use warnings;

use App::cpanminus::reporter;
use Getopt::Long;
use Pod::Usage;

my %options = ();
GetOptions( \%options, qw(build_dir=s build_logfile=s) ) or pod2usage();

my $tester = App::cpanminus::reporter->new( %options );

$tester->run();

__END__

=head1 WARNING: WORK IN PROGRESS AHEAD

This is a work in progress for now. If you care, please look for garu, xdg, barbie or miyagawa on irc.perl.org. Cheers.

=head1 SYNOPSIS

Basic usage (for now, meaning developers only!!):

   > mkdir /tmp/reporter

   > cpanm Some::Module    # do *NOT* pass -v to cpanm!!
   (wait for it to finish)

   > cpanm-reporter

OPTIONAL ARGUMENTS

   --build_dir=PATH       Where your build directory is, containing
                          each dist's subdir. Default: $HOME/.cpanm/latest-build

   --build_logfile=PATH   Where the build.log is. Default: $BUILD_DIR/build.log


Then check out STDERR for messages, and /tmp/reporter to see the emails that will be sent to CPAN Testers!

CAVEAT

cpanm currently does not record the output into your build.log file if you pass the "verbose" argument to it,
either C<--verbose> or C<-v>. If you used those, we won't be able to send any reports :(
