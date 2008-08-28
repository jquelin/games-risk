#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk;

use 5.010;
use strict;
use warnings;

use Games::Risk::GUI::Board;
use Games::Risk::Map;
use Games::Risk::Player;
use List::Util   qw{ shuffle };
use Module::Util qw{ find_installed };
use POE;


# Public variables of the module.
our $VERSION = '0.0.1';

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            _start         => \&_onpriv_start,
            _stop          => sub { warn "GR shutdown\n" },
            # public events
            board_ready      => \&_onpub_gui_ready,
        },
    );
    return $session->ID;
}


#--
# Events

# -- public events

sub _onpub_gui_ready {
    my ($k, $h) = @_[KERNEL, HEAP];

    $k->post('board', 'load_map', $h->{model}->background);

    # create players - FIXME: number of players
    my @players;
    push @players, Games::Risk::Player->new;
    push @players, Games::Risk::Player->new;
    push @players, Games::Risk::Player->new;
    push @players, Games::Risk::Player->new;
    
    @players = shuffle @players; 

    #FIXME: broadcast
    foreach my $player ( @players ) {
        $k->post('board', 'newplayer', $player);
    }

    $h->{players}   = \@players;
    $h->{curplayer} = 0;
}


# -- private events


#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($k, $h) = @_[KERNEL, HEAP];

    $k->alias_set('risk');

    # load model
    # FIXME: hardcoded
    my $path = find_installed(__PACKAGE__);
    $path =~ s/\.pm$//;
    $path .= '/maps/risk.map';
    my $model = Games::Risk::Model->new;
    $model->load_file($path);
    $h->{model} = $model;


    Games::Risk::GUI::Board->spawn({toplevel=>$poe_main_window});
}




1;
__END__

=head1 NAME

Games::Risk - a generic funge interpreter


=head1 SYNOPSIS

    use Games::Risk;
    my $interp = Games::Risk->new( { file => 'program.bf' } );
    $interp->run_code( "param", 7, "foo" );

    Or, one can write directly:
    my $interp = Games::Risk->new;
    $interp->store_code( <<'END_OF_CODE' );
    < @,,,,"foo"a
    END_OF_CODE
    $interp->run_code;


=head1 DESCRIPTION

Enter the realm of topological languages!

This module implements the Funge-98 specifications on a 2D field (also
called Befunge). It can also work as a n-funge implementation (3D and
more).

This Befunge-98 interpreters assumes the stack and Funge-Space cells
of this implementation are 32 bits signed integers (I hope your os
understand those integers). This means that the torus (or Cartesian
Lahey-Space topology to be more precise) looks like the following:

              32-bit Befunge-98
              =================
                      ^
                      |-2,147,483,648
                      |
                      |         x
          <-----------+----------->
  -2,147,483,648      |      2,147,483,647
                      |
                     y|2,147,483,647
                      v


This module also implements the Concurrent Funge semantics.


=head1 PUBLIC METHODS

=head2 new( [params] )

Call directly the C<Games::Risk::Interpreter> constructor. Refer
to L<Games::Risk::Interpreter> for more information.


=head1 TODO

=over 4

=item o

Write standard libraries.

=back


=head1 BUGS

Although this module comes with a full set of tests, maybe there are
subtle bugs - or maybe even I misinterpreted the Funge-98
specs. Please report them to me.

There are some bugs anyway, but they come from the specs:

=over 4

=item o

About the 18th cell pushed by the C<y> instruction: Funge specs just
tell to push onto the stack the size of the stacks, but nothing is
said about how user will retrieve the number of stacks.

=item o

About the load semantics. Once a library is loaded, the interpreter is
to put onto the TOSS the fingerprint of the just-loaded library. But
nothing is said if the fingerprint is bigger than the maximum cell
width (here, 4 bytes). This means that libraries can't have a name
bigger than C<0x80000000>, ie, more than four letters with the first
one smaller than C<P> (C<chr(80)>).

Since perl is not so rigid, one can build libraries with more than
four letters, but perl will issue a warning about non-portability of
numbers greater than C<0xffffffff>.

=back


=head1 ACKNOWLEDGEMENTS

I would like to thank Chris Pressey, creator of Befunge, who gave a
whole new dimension to both coding and obfuscating.


=head1 SEE ALSO

=over 4

=item L<perl>

=item L<http://www.catseye.mb.ca/esoteric/befunge/>

=item L<http://dufflebunk.iwarp.com/JSFunge/spec98.html>

=back


=head1 AUTHOR

Jerome Quelin, E<lt>jquelin@cpan.orgE<gt>

Development is discussed on E<lt>games-risk@mongueurs.netE<gt>


=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.


=cut
