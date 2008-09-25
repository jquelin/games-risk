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
use List::Util qw{ shuffle };
use POE;
use Readonly;
use Tk;
use Tk::Balloon;
use Tk::BrowseEntry;
use Tk::Font;

use aliased 'POE::Kernel' => 'K';

Readonly my $WAIT_CLEAN_AI    => 1.000;
Readonly my $WAIT_CLEAN_HUMAN => 0.250;

Readonly my @COLORS => (
    '#333333',  # grey20
    '#FF2052',  # awesome
    '#01A368',  # green
    '#0066FF',  # blue
    '#9E5B40',  # sepia
    '#A9B2C3',  # cadet blue
    '#BB3385',  # red violet
    '#FF681F',  # orange
    '#DCB63B',  # ~ dirty yellow
    '#00CCCC',  # robin's egg blue
    #'#1560BD',  # denim
    #'#33CC99',  # shamrock
    #'#FF9966',  # atomic tangerine
    #'#00755E',  # tropical rain forest
    #'#A50B5E',  # jazzberry jam
    #'#A3E3ED',  # blizzard blue
);
Readonly my @NAMES => (
    'Napoleon Bonaparte',   # france,   1769  - 1821
    'Staline',              # russia,   1878  - 1953
    'Alexander the Great',  # greece,   356BC - 323BC
    'Julius Caesar',        # rome,     100BC - 44BC
    'Attila',               # hun,      406   - 453
    'Genghis Kahn',         # mongolia, 1162  - 1227
    'Charlemagne',          # france,   747   - 814
    'Saladin',              # iraq,     1137  - 1193
    'Otto von Bismarck',    # germany,  1815  - 1898
    'Ramses II',            # egypt,    1303BC - 1213BC
);



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
            _load_defaults       => \&_onpriv_load_defaults,
            _new_player          => \&_onpriv_new_player,
            # private events - game
            # gui events
            _but_quit            => \&_ongui_but_quit,
            _but_start           => \&_ongui_but_start,
            # public events
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events


# -- private events

sub _onpriv_load_defaults {
    my ($h, $s) = @_[HEAP, SESSION];

    # FIXME: hardcoded
    my @names  = ($ENV{USER}, shuffle @NAMES );
    my @types  = ('Human', ('Computer, easy')x2, ('Computer, hard')x3);
    my @colors = @COLORS;
    foreach my $i ( 0..5 ) {
        K->yield('_new_player', $names[$i], $types[$i], $colors[$i]);
    }
}


#
# event: _new_player([$name], [)
#
#
sub _onpriv_new_player {
    my ($h, $s, @args) = @_[HEAP, SESSION, ARG0..$#_];

    my ($name, $type, $color) = @args;
    my @players = @{ $h->{players} };
    my $num = scalar @players;
    my @choices = ( 'Human', 'Computer, easy', 'Computer, hard' );

    # the frame
    $h->{players}[$num]{name} = $name;
    $h->{players}[$num]{type} = $type;
    my $f = $h->{frame}{players}->Frame(-bg=>$color)->pack(@TOP, @FILLX);
    my $e = $f->Entry(
        -textvariable => \$h->{players}[$num]{name}
    )->pack(@LEFT,@XFILLX);
    my $be = $f->BrowseEntry(
        -variable           => \$h->{players}[$num]{type},
        -listheight         => scalar(@choices)+1,
        -choices            => \@choices,
        -state              => 'readonly',
        -disabledforeground => 'black',
    )->pack(@LEFT);
}


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

    #-- initializations
    $h->{players} = [];

    #-- title
    my $font = $top->Font(-size=>16);
    my $title = $top->Label(
        -bg   => 'black',
        -fg   => 'white',
        -font => $font,
        -text => 'New game',
    )->pack(@TOP,@PAD20,@FILLX);

    #-- various resources

    # load images
    # FIXME: this should be in a sub/method somewhere

    # ballon
    $h->{balloon} = $top->Balloon;

    #-- frame for players
    my $fpl = $top->Frame->pack(@TOP, @XFILL2, @PAD20);
    $fpl->Label(-text=>'Players', -anchor=>'w')->pack(@TOP, @FILLX);
    $h->{frame}{players} = $fpl;
    K->yield('_load_defaults');

    #-- bottom frame
    my $fbot = $top->Frame->pack(@BOTTOM, @FILLX, @PAD20);
    my $b_start = $fbot->Button(
        -text => 'Start game',
        -command => $s->postback('_but_start'),
    );
    my $b_quit = $fbot->Button(
        -text => 'Quit',
        -command => $s->postback('_but_quit'),
    );
    # pack after creation, to have clean focus order
    $b_quit->pack(@RIGHT,@PAD1);
    $b_start->pack(@RIGHT,@PAD1);

    # window binding
    $top->bind('<Key-Return>', $s->postback('_but_start'));
    $top->bind('<Key-Escape>', $s->postback('_but_quit'));

}

# -- gui events

#
# event: _but_quit()
#
# called when button quit is clicked, ie user wants to cancel new game.
# effectively kills the application.
#
sub _ongui_but_quit {
    my $h = $_[HEAP];
    K->post('risk', 'quit');
    K->alias_remove('startup');
    $h->{toplevel}->destroy; # this should be enough by itself
}


#
# event: _but_start()
#
# called when button start is clicked. signal controller to really load
# a game.
#
sub _ongui_but_start {
    my $h = $_[HEAP];

    K->post('risk', 'new_game', { players => $h->{players} } );
    $h->{toplevel}->withdraw;
}



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

