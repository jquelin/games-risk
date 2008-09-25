#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::Startup;

use 5.010;
use strict;
use warnings;

use Games::Risk::GUI::Constants;
use POE;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::Font;

use aliased 'POE::Kernel' => 'K';

Readonly my $WAIT_CLEAN_AI    => 1.000;
Readonly my $WAIT_CLEAN_HUMAN => 0.250;


#--
# Constructor

#
# my $id = Games::Risk::GUI->spawn( \%params );
#
# create a new window containing the board used for the game. refer
# to the embedded pod for an explanation of the supported options.
#
sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events - session
            _start               => \&_onpriv_start,
            _stop                => sub { warn "gui-startup shutdown\n" },
            # private events - game
            # gui events
            # public events
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events


# -- private events


#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($h, $s, $args) = @_[HEAP, SESSION, ARG0];

    K->alias_set('startup');
    my $top = $h->{toplevel} = $args->{toplevel};

    #-- title
    my $font = $top->Font(-size=>16);
    my $title = $top->Label(
        -bg   => 'black',
        -fg   => 'white',
        -font => $font,
        -text => 'New game',
    )->pack(@TOP,@PAD20,@XFILL2);

    #-- various resources

    # load images
    # FIXME: this should be in a sub/method somewhere

    # ballon
    $h->{balloon} = $top->Balloon;


    #-- main frames
    my $fleft  = $top->Frame->pack(@LEFT,  @XFILL2);
    my $fright = $top->Frame->pack(@RIGHT, @FILL2);


    #-- frame for game state
    my $fgs = $fleft->Frame->pack(@TOP, @FILLX);
    $fgs->Label(-text=>'Game state: ')->pack(@LEFT);
    my $labp = $fgs->Label(-text=>'place armies', @ENOFF)->pack(@LEFT, @XFILL2);
    my $but_predo = $fgs->Button(
        -command => $s->postback('_but_place_armies_redo'),
        -image   => $h->{images}{actreload16},
        @ENOFF,
    )->pack(@LEFT);
    my $but_pdone = $fgs->Button(
        -command => $s->postback('_but_place_armies_done'),
        -image   => $h->{images}{navforward16},
        @ENOFF,
    )->pack(@LEFT);
    my $laba = $fgs->Label(-text=>'attack', @ENOFF)->pack(@LEFT, @XFILL2);
    my $but_aredo = $fgs->Button(
        -command => $s->postback('_but_attack_redo'),
        -image   => $h->{images}{actredo16},
        @ENOFF,
    )->pack(@LEFT);
    my $but_adone = $fgs->Button(
        -command => $s->postback('_but_attack_done'),
        -image   => $h->{images}{navforward16},
        @ENOFF,
    )->pack(@LEFT);
    my $labm = $fgs->Label(-text=>'move armies', @ENOFF)->pack(@LEFT, @XFILL2);
    my $but_mdone = $fgs->Button(
        -command => $s->postback('_but_move_armies_done'),
        -image   => $h->{images}{playstop16},
        @ENOFF,
    )->pack(@LEFT);
    $h->{labels}{place_armies} = $labp;
    $h->{labels}{attack}       = $laba;
    $h->{labels}{move_armies}  = $labm;
    $h->{buttons}{place_armies_redo} = $but_predo;
    $h->{buttons}{place_armies_done} = $but_pdone;
    $h->{buttons}{attack_redo}       = $but_aredo;
    $h->{buttons}{attack_done}       = $but_adone;
    $h->{buttons}{move_armies_done}  = $but_mdone;
    $h->{balloon}->attach($but_predo, -msg=>'undo all');
    $h->{balloon}->attach($but_pdone, -msg=>'ready for attack');
    $h->{balloon}->attach($but_aredo, -msg=>'attack again');
    $h->{balloon}->attach($but_adone, -msg=>'consolidate');
    $h->{balloon}->attach($but_mdone, -msg=>'turn finished');


    #-- canvas
    my $c = $fleft->Canvas->pack(@TOP,@XFILL2);
    $h->{canvas} = $c;
    $c->CanvasBind( '<Motion>', [$s->postback('_canvas_motion'), Ev('x'), Ev('y')] );
    # removing class bindings
    foreach my $button ( qw{ 4 5 6 7 } ) {
        $top->bind('Tk::Canvas', "<Button-$button>",       undef);
        $top->bind('Tk::Canvas', "<Shift-Button-$button>", undef);
    }
    foreach my $key ( qw{ Down End Home Left Next Prior Right Up } ) {
        $top->bind('Tk::Canvas', "<Key-$key>", undef);
        $top->bind('Tk::Canvas', "<Control-Key-$key>", undef);
    }


    #-- bottom frame
    # the status bar
    $h->{status} = '';
    my $fbot = $fleft->Frame->pack(@BOTTOM, @FILLX);
    $fbot->Label(
        -anchor       =>'w',
        -textvariable => \$h->{status},
    )->pack(@LEFT,@XFILLX, @PAD1);

    # label to display country pointed by mouse
    $h->{country}       = undef;
    $h->{country_label} = '';
    $fbot->Label(
        -anchor       => 'e',
        -textvariable => \$h->{country_label},
    )->pack(@RIGHT, @XFILLX, @PAD1);


     #-- players frame
    my $fpl = $fright->Frame->pack(@TOP);
    $fpl->Label(-text=>'Players')->pack(@TOP);
    my $fplist = $fpl->Frame->pack(@TOP);
    $h->{frames}{players} = $fplist;


    #-- dices frame
    my $fdice = $fright->Frame->pack(@TOP,@FILLX, -pady=>10);
    $fdice->Label(-text=>'Dice arena')->pack(@TOP,@FILLX);
    my $fd1 = $fdice->Frame->pack(@TOP,@FILL2);
    my $a1 = $fd1->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $a2 = $fd1->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $a3 = $fd1->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $fd3 = $fdice->Frame->pack(@TOP,@FILL2);
    my $r1 = $fd3->Label(
        -image => $h->{images}{empty16},
        -width => 38,
    )->pack(@LEFT);
    my $r2 = $fd3->Label(
        -image => $h->{images}{empty16},
        -width => 38,
    )->pack(@LEFT);
    my $fd2 = $fdice->Frame->pack(@TOP,@FILL2);
    my $d1 = $fd2->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    my $d2 = $fd2->Label(-image=>$h->{images}{dice_0})->pack(@LEFT);
    $h->{labels}{attack_1}  = $a1;
    $h->{labels}{attack_2}  = $a2;
    $h->{labels}{attack_3}  = $a3;
    $h->{labels}{result_1}  = $r1;
    $h->{labels}{result_2}  = $r2;
    $h->{labels}{defence_1} = $d1;
    $h->{labels}{defence_2} = $d2;


    #-- other window
    Games::Risk::GUI::Cards->spawn({parent=>$top});
    Games::Risk::GUI::MoveArmies->spawn({parent=>$top});

    #-- say that we're done
    K->post('risk', 'window_created', 'board');

}

# -- gui events


1;

__END__


=head1 NAME

Games::Risk::GUI::Startup - startup window



=head1 SYNOPSIS

    my $id = Games::Risk::GUI::Startup->spawn(\%params);



=head1 DESCRIPTION

This class implements a poe session responsible for the startup window
of the GUI. It allows to design the new game to be played.



=head1 METHODS


=head2 my $id = Games::Risk::GUI::Startup->spawn( )



=begin quiet_pod_coverage

=item * K

=end quiet_pod_coverage




=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

