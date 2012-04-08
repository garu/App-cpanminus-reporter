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
