use 5.010;
use strict;
use warnings;

package Games::Risk::App::Command::play;
# ABSTRACT: play a risk game

use Games::Risk::App -command;


# -- public methods

sub description { 'Play a Risk game.'; }

sub opt_spec {
    my $self = shift;
    return (
        [],
    );
}

sub execute {
    my ($self, $opts, $args) = @_;

    require Games::Risk;
    Games::Risk->run;
}


1;
__END__


=head1 DESCRIPTION

This command launch a prisk game. Most of the time, this is what you
want to do.
