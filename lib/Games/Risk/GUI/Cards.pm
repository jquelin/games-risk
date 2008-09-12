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

use File::Basename qw{ fileparse };
use List::Util qw{ max };
use Module::Util   qw{ find_installed };
use POE;
use Tk;

use aliased 'POE::Kernel' => 'K';

my @TOP     = ( -side => 'top'    );
my @BOTTOM  = ( -side => 'bottom' );
my @LEFT    = ( -side => 'left'   );
my @RIGHT   = ( -side => 'right'  );

my @FILLX   = ( -fill => 'x'    );
my @FILL2   = ( -fill => 'both' );
my @XFILLX  = ( -expand => 1, -fill => 'x'    );
my @XFILL2  = ( -expand => 1, -fill => 'both' );

my @PAD1    = ( -padx => 1, -pady => 1);
my @PAD20   = ( -padx => 20, -pady => 20);

my @ENON    = ( -state => 'normal' );
my @ENOFF   = ( -state => 'disabled' );




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
            _start     => \&_onpriv_start,
            _stop                => sub { warn "gui-cards shutdown\n" },
            # gui events
            # public events
            card       => \&_onpub_card,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events

#
# event: card( $card );
#
# player just received a new $card, display it.
#
sub _onpub_card {
    my ($h, $card) = @_[HEAP, ARG0];

    # update gui
    my $top = $h->{toplevel};

    # move window & enforce geometry
    $top->update;               # force redraw

    #$top->resizable(0,0);
    #my ($maxw,$maxh) = $top->geometry =~ /^(\d+)x(\d+)/;
    #$top->maxsize($maxw,$maxh); # bug in resizable: minsize in effet but not maxsize
}


# -- private events

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

    #- load pictures
    # FIXME: this should be in a sub/method somewhere
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    $h->{images}{"card-$_"} = $top->Photo(-file=>"$dirname/icons/card-$_.png")
        foreach qw{ bg artillery cavalry infantry jocker };

    # -- top frame
    my $f = $top->Scrolled('Frame',
        -scrollbars => 'e',
        -width      => 95*3,
        -height     => 150,
    )->pack(@TOP, @XFILL2);

    #- bottom button
    my $b = $top->Button(
        -text => 'Exchange',
        @ENOFF,
    )->pack(@TOP, @FILL2);

=pod

    my $lab = $top->Label->pack(@TOP,@XFILL2);
    my $fs  = $top->Frame->pack(@TOP,@XFILL2);
    $fs->Label(-text=>'Armies to move')->pack(@LEFT);
    $h->{armies} = 0;  # nb of armies to move
    my $sld = $fs->Scale(
        -orient    => 'horizontal',
        -width     => 5, # height since we're horizontal
        -showvalue => 1,
        -variable  => \$h->{armies},
    )->pack(@LEFT,@XFILL2);
    my $but = $top->Button(
        -text    => 'Move armies',
        -command => $s->postback('_but_move'),
    )->pack(@TOP);
    $h->{lab_title} = $title;
    $h->{lab_info}  = $lab;
    $h->{but_move}  = $but;
    $h->{scale}     = $sld;

    # window bindings.
    $top->bind('<4>', $s->postback('_slide_wheel',  1));
    $top->bind('<5>', $s->postback('_slide_wheel', -1));
    $top->bind('<Key-Return>', $s->postback('_but_move'));
    $top->bind('<Key-space>', $s->postback('_but_move'));


    #-- trap some events
    $top->protocol( WM_DELETE_WINDOW => sub{} );

=cut

}


# -- gui events

#
# event: _but_move()
#
# click on the move button, decide to move armies.
#
sub _onpriv_but_move {
    my $h = $_[HEAP];
    K->post($h->{replyto}, $h->{reply}, $h->{src}, $h->{dst}, $h->{armies});
    $h->{toplevel}->withdraw;
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

