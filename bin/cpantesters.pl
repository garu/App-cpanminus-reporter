# TODO - try it with these:
# illguts
# DBIx::Class::Manual::SQLHackers
# TODO - does cpanm work like "cpan ."? This might not have the Fetching/Entering bits
# TODO - get_config_file => Config::Tiny->read( .cpanreporter/config )
use 5.14.0;
use warnings;

use App::cpantesters;

# TODO: getopt for cpanm_dir && build_logfile
my $tester = App::cpantesters->new;

$tester->run();

__END__

=head1 WARNING: WORK IN PROGRESS AHEAD

This is a work in progress for now. If you care, please look for garu, xdg, barbie or miyagawa on irc.perl.org. Cheers.

=head1 SYNOPSIS

Basic usage (for now, meaning developers only!!):

   > mkdir /tmp/reporter

   > cpanm Some::Module
   (wait for it to finish)

   > cpantesters

Then check out STDERR for messages, and /tmp/reporter to see the emails that will be sent to CPAN Testers!

