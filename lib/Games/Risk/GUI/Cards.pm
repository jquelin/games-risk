#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::Cards;

use 5.010;
use strict;
use warnings;

use Games::Risk::GUI::Constants;
use Games::Risk::Resources qw{ image };
use List::MoreUtils qw{ any firstidx };
use POE;
use Readonly;
use Tk::Pane;

use aliased 'POE::Kernel' => 'K';

Readonly my $WIDTH  => 95;
Readonly my $HEIGHT => 145;


#--
# Constructor

#
# my $id = Games::Risk::GUI::Card->spawn( \%params );
#
# create a new window to list cards owned by the player. refer to the
# embedded pod for an explanation of the supported options.
#
sub spawn {
    my ($class, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events - session mgmt
            _start               => \&_onpriv_start,
            _stop                => sub { warn "gui-cards shutdown\n" },
            # private events
            _change_button_state => \&_onpub_change_button_state,
            _redraw_cards        => \&_onpriv_redraw_cards,
            # gui events
            _card_clicked        => \&_ongui_card_clicked,
            _but_exchange        => \&_ongui_but_exchange,
            # public events
            attack               => \&_onpub_change_button_state,
            card_add             => \&_onpub_card_add,
            card_del             => \&_onpub_card_del,
            place_armies         => \&_onpub_change_button_state,
            shutdown             => \&_onpub_shutdown,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events

#
# event: card_add( $card );
#
# player just received a new $card, display it.
#
sub _onpub_card_add {
    my ($h, $card) = @_[HEAP, ARG0];

    my $cards = $h->{cards};
    push @$cards, $card;

    K->yield('_redraw_cards');
}


#
# event: card_del( @cards );
#
# player just exchange some @cards, remove them.
#
sub _onpub_card_del {
    my ($h, @del) = @_[HEAP, ARG0..$#_];

    # nothing selected any more
    $h->{selected} = [];
    $h->{bonus}    = 0;
    $h->{label}->configure(-text=>'Select 3 cards');

    # remove the cards
    my @cards = @{ $h->{cards} };
    my %left; @left{ @cards } = ();
    delete @left{ @del };
    my @left = grep { exists $left{$_} } @cards;
    $h->{cards} = \@left;

    K->yield('_redraw_cards');
    K->yield('_change_button_state');
}


#
# event: attack()
# event: place_armies()
# event: _change_button_state()
#
# change button state depending on the game state and the cards
# selected.
#
sub _onpub_change_button_state {
    my ($h, $event) = @_[HEAP, STATE];

    my $select;
    given ($event) {
        when ('attack') {
            $h->{state} = 'attack';
            $select     = 0;
        }
        when ('place_armies') {
            $h->{state} = 'place_armies';
            $select     = $h->{bonus};
        }
        default {
            $select = $h->{state} eq 'place_armies' && $h->{bonus};
        }
    }

    $h->{button}->configure( $select ? @ENON : @ENOFF );
}


#
# event: shutdown()
#
# kill current session. the toplevel window has already been destroyed.
#
sub _onpub_shutdown {
    my $h = $_[HEAP];
    K->alias_remove('cards');
}

# -- private events

#
# event: _redraw_cards()
#
# ask to discard current cards shown, and redraw them. used when
# receiving a new card, or after exchanging some of them.
#
sub _onpriv_redraw_cards {
    my ($h, $s) = @_[HEAP, SESSION];

    # removing cards
    my $canvases = $h->{canvases} // [];
    $_->destroy for @$canvases;

    # update gui
    my @canvases;
    my @selected = @{ $h->{selected} // [] };
    my $cards = $h->{cards};
    foreach my $i ( 0 .. $#$cards ) {
        my $card = $cards->[$i];
        my $country = $card->country;

        #
        my $is_selected = any { $_ == $i } @selected;

        # the canvas containing country info
        my $row = int( $i / 3 );
        my $col = $i % 3;
        my $c = $h->{frame}->Canvas(
            -width  => $WIDTH,
            -height => $HEIGHT,
            -bg     => $is_selected ? 'black' : 'white',
        )->grid(-row=>$row,-column=>$col);
        $c->CanvasBind('<1>', [$s->postback('_card_clicked'), $card]);

        # the info themselves
        $c->createImage(1, 1, -anchor=>'nw', -image=>image('card-bg'), -tags=>['bg']);
        if ( $card->type eq 'joker' ) {
            # only the joker!
            $c->createImage(
                $WIDTH/2, $HEIGHT/2,
                -image  => image('card-joker'),
            );
        } else {
            # country name
            $c->createText(
                $WIDTH/2, 15,
                -width  => 70,
                -anchor => 'n',
                -text   => $country->name,
            );
            # type of card
            $c->createImage(
                $WIDTH/2, $HEIGHT-10,
                -anchor => 's',
                -image  => image('card-' . $card->type),
            );
        }

        # storing canvas
        push @canvases, $c;
    }

    $h->{canvases} = \@canvases;

    #$h->{frame}->configure(-width=>95*3,-height=>175*scalar(@hframes));

    # move window & enforce geometry
    #$top->update;               # force redraw

    #$top->resizable(0,0);
    #my ($maxw,$maxh) = $top->geometry =~ /^(\d+)x(\d+)/;
    #$top->maxsize($maxw,$maxh); # bug in resizable: minsize in effet but not maxsize
}


#
# event: _start( \%opts );
#
# session initialization. \%params is received from spawn();
#
sub _onpriv_start {
    my ($h, $s, $opts) = @_[HEAP, SESSION, ARG0];

    K->alias_set('cards');

    #-- create gui

    my $top = $opts->{parent}->Toplevel;
    #$top->withdraw;           # window is hidden first
    $h->{toplevel} = $top;
    $top->title('Cards');

    #- top label
    $h->{label} = $top->Label(
        -text => 'Select 3 cards')->pack(@TOP,@FILLX);

    #- cards frame
    $h->{frame} = $top->Scrolled('Frame',
        -scrollbars => 'e',
        -width      => ($WIDTH+5)*3,
        -height     => ($HEIGHT+5)*2,
    )->pack(@TOP, @XFILL2);

    #- bottom button
    $h->{button} = $top->Button(
        -text    => 'Exchange cards',
        -command => $s->postback('_but_exchange'),
        @ENOFF,
    )->pack(@TOP, @FILL2);

    #- force window geometry
    $top->update;    # force redraw
    $top->resizable(0,0);

    #- window bindings.
    #$top->bind('<4>', $s->postback('_slide_wheel',  1));
    #$top->bind('<5>', $s->postback('_slide_wheel', -1));


    # -- inits
    $h->{cards} = [];


    #-- trap some events
    $top->protocol( WM_DELETE_WINDOW => sub{} );
}


# -- gui events

#
# event: _but_exchange()
#
# click on the exchange button, to trade armies.
#
sub _ongui_but_exchange {
    my $h = $_[HEAP];

    # get the lists
    my @cards    = @{ $h->{cards} };
    my @selected = @{ $h->{selected} };

    my @exchange = map { $cards[$_] } @selected;
    K->post('risk', 'cards_exchange', @exchange);
}


#
# event: _card_clicked()
#
# click on a card, changing its selected status.
#
sub _ongui_card_clicked {
    my ($h, $args) = @_[HEAP, ARG1];
    my ($canvas, $card) = @$args;

    # get the lists
    my @cards    = @{ $h->{cards} };
    my @canvases = @{ $h->{canvases} };
    my @selected = @{ $h->{selected} // [] };

    # get index of clicked canvas, and its select status
    my $idx = firstidx { $_ eq $canvas } @canvases;
    my $is_selected = any { $_ == $idx } @selected;

    # change card status: de/selected
    if ( $is_selected ) {
        # deselect
        $canvas->configure(-bg=>'white');
        @selected = grep { $_ != $idx } @selected;
    } else {
        # select
        $canvas->configure(-bg=>'black');
        push @selected, $idx;
    }


    if ( scalar(@selected) == 3 ) {
        # get types of armies
        my @types = sort map { $cards[$_]->type } @selected;

        # compute how much armies it's worth.
        my $combo = join '', map { substr $_, 0, 1 } @types;
        my $bonus;
        given ($combo) {
            when ( [ qw{ aci acj aij cij ajj cjj ijj jjj } ] ) { $bonus = 10; }
            when ( [ qw{ aaa aaj } ] ) { $bonus = 8; }
            when ( [ qw{ ccc ccj } ] ) { $bonus = 6; }
            when ( [ qw{ iii iij } ] ) { $bonus = 4; }
            default { $bonus = 0; }
        }
        $h->{bonus} = $bonus;

        # update label
        local $" = ', ';
        my $text  = "@types = $bonus armies";
        $h->{label}->configure(-text=>$text);

    } else {
        # update label
        $h->{label}->configure(-text=>'Select 3 cards');
        $h->{bonus} = 0;
    }

    # FIXME: check validity of cards selected
    #$top->bind('<Key-Return>', $s->postback('_but_move'));
    #$top->bind('<Key-space>',  $s->postback('_but_move'));

    # store new set of selected cards
    $h->{selected} = \@selected;

    K->yield('_change_button_state');
}


#
# event: _slide_wheel([$diff])
#
# mouse wheel on the slider, with an increment of $diff (can be negative
# too).
#
sub _onpriv_slide_wheel {
    my ($h, $args) = @_[HEAP, ARG0];
    $h->{armies} += $args->[0];
}


1;

__END__


=head1 NAME

Games::Risk::GUI::Cards - cards listing



=head1 SYNOPSYS

    my $id = Games::Risk::GUI::Cards->spawn(%opts);
    Poe::Kernel->post( $id, 'card', $card );



=head1 DESCRIPTION

C<GR::GUI::Cards> implements a POE session, creating a Tk window to
list the cards the player got. It can be used to exchange cards with new
armies during reinforcement.



=head1 CLASS METHODS


=head2 my $id = Games::Risk::GUI::Cards->spawn( %opts );

Create a window requesting for amies move, and return the associated POE
session ID. One can pass the following options:

=over 4

=item parent => $mw

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.


=back


=begin quiet_pod_coverage

=item * K

=end quiet_pod_coverage



=head1 PUBLIC EVENTS

The newly created POE session accepts the following events:


=over 4

=item card( $card )

Add C<$card> to the list of cards owned by the player to be shown.


=back



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

