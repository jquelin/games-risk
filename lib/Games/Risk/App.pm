use 5.010;
use strict;
use warnings;

package Games::Risk::App;
# ABSTRACT: prisk's App::Cmd

use App::Cmd::Setup -app;

sub allow_any_unambiguous_abbrev { 1 }
sub default_args                 { [ 'play' ] }

1;
__END__

=head1 DESCRIPTION

This is the main application, based on the excellent L<App::Cmd>.
Nothing much to see here, see the various subcommands available for more
information, or run one of the following:

    prisk commands
    prisk help

Note that each subcommand can be abbreviated as long as the abbreviation
is unambiguous.
