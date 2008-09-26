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

use File::Basename qw{ fileparse };
use Games::Risk::GUI::Constants;
use List::Util     qw{ shuffle };
use List::MoreUtils qw{ any };
use Module::Util   qw{ find_installed };
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
            _check_errors        => \&_onpriv_check_errors,
            _check_nb_players    => \&_onpriv_check_nb_players,
            _load_defaults       => \&_onpriv_load_defaults,
            _new_player          => \&_onpriv_new_player,
            _player_color        => \&_onpriv_player_color,
            # private events - game
            # gui events
            _but_color           => \&_ongui_but_color,
            _but_delete          => \&_ongui_but_delete,
            _but_new_player      => \&_ongui_but_new_player,
            _but_quit            => \&_ongui_but_quit,
            _but_start           => \&_ongui_but_start,
            # public events
            new_game             => \&_onpub_new_game,
        },
    );
    return $session->ID;
}


#--
# EVENT HANDLERS

# -- public events

sub _onpub_new_game {
    my $h = $_[HEAP];
    $h->{toplevel}->deiconify;
}


# -- private events

#
# event: _check_errors()
#
# check various config errors, such as player without a name, 2 human
# players, etc. disable start game if any error spotted.
#
sub _onpriv_check_errors {
    my ($h, $s) = @_[HEAP, SESSION];

    my $players = $h->{players};
    my @players = grep { defined $_ } @$players;
    my $top = $h->{toplevel};
    my $errstr;

    # remove previous error message
    if ( $h->{error} ) {
        # remove label
        $h->{error}->destroy;
        $h->{error} = undef;

        # allow start to be clicked
        $h->{button}{start}->configure(@ENON);
        $top->bind('<Key-Return>', $s->postback('_but_start'));
    }

    # 2 players cannot have the same color
    my %colors;
    @colors{ map { $_->{color} } @players } = (0) x @players;
    $colors{ $_->{color} }++ for @players;
    $errstr = 'Two players cannot have the same color.'
        if any { $colors{$_} > 1 } keys %colors;

    # 2 players cannot have the same name
    my %names;
    @names{ map { $_->{name} } @players } = (0) x @players;
    $names{ $_->{name} }++ for @players;
    $errstr = 'Two players cannot have the same name.'
        if any { $names{$_} > 1 } keys %names;

    # human players
    my $nbhuman = grep { $_->{type} eq 'Human' } @players;
    $errstr = 'Cannot have more than one human player.'            if $nbhuman > 1;
    $errstr = 'Game without any human player not (yet) supported.' if $nbhuman < 1;

    # all players should have a name
    $errstr = 'A player cannot have an empty name.'
        if any { $_->{name} eq '' } @players;

    # there should be at least 2 players
    $errstr = 'Game should have at least 2 players.' if scalar @players < 2;

    # check if there are some errors
    if ( $errstr ) {
        # add warning
        $h->{error} = $h->{frame}{players}->Label(
            -bg => 'red',
            -text => $errstr,
        )->pack(@TOP, @FILLX);

        # prevent start to be clicked
        $h->{button}{start}->configure(@ENOFF);
        $top->bind('<Key-Return>', undef);
    }
}


#
# event: _check_nb_players
#
# check whether one can add new players.
#
sub _onpriv_check_nb_players {
    my $h = $_[HEAP];

    my $players = $h->{players};
    my @players = grep { defined $_ } @$players;

    # check whether we can add another player
    my @config = ( scalar(@players) >= 10 ) ? @ENOFF : @ENON;
    $h->{button}{add_player}->configure(@config);
}


#
# _load_defaults()
#
# load default players, currently hardcoded (FIXME), but later from the
# last choices (saved in a config file somewhere).
#
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
# fired when there's a new player created.
#
sub _onpriv_new_player {
    my ($h, $s, @args) = @_[HEAP, SESSION, ARG0..$#_];

    my ($name, $type, $color) = @args;
    my $players = $h->{players};
    my $num = scalar @$players;
    my @choices = ( 'Human', 'Computer, easy', 'Computer, hard' );

    # the frame
    $players->[$num]{name}  = $name;
    $players->[$num]{type}  = $type;
    $players->[$num]{color} = $color;
    my $fpl = $h->{frame}{players}->Frame
        ->pack(@TOP, @FILLX, -before=>$h->{button}{add_player});
    my $f = $fpl->Frame(-bg=>$color)->pack(@LEFT, @FILLX);
    $players->[$num]{line}  = $fpl;
    $players->[$num]{frame} = $f;
    my $e = $f->Entry(
        -textvariable => \$players->[$num]{name},
        -validate     => 'all',
        -vcmd         => sub { $s->postback('_check_errors')->(); 1; },
        #-highlightbackground => $color,
    )->pack(@LEFT,@XFILLX);
    my $be = $f->BrowseEntry(
        -variable           => \$players->[$num]{type},
        -background         => $color,
        -listheight         => scalar(@choices)+1,
        -choices            => \@choices,
        -state              => 'readonly',
        -disabledforeground => 'black',
        -browsecmd          => $s->postback('_check_errors'),
    )->pack(@LEFT);
    my $bc = $f->Button(
        -bg               => $color,
        -fg               => 'white',
        -activebackground => $color,
        -activeforeground => 'white',
        -image            => $h->{images}{paint},
        -command          => $s->postback('_but_color', $num),
    )->pack(@LEFT);
    my $ld = $fpl->Label(-image=>$h->{images}{fileclose16})->pack(@LEFT);
    $ld->bind('<1>', $s->postback('_but_delete', $num));
    $players->[$num]{be_type}   = $be;
    $players->[$num]{but_color} = $bc;

    # max players reached?
    K->yield('_check_nb_players');
}


#
# event: _player_color( [$num, $color] )
#
# called to change color of player number $num to $color.
#
sub _onpriv_player_color {
    my ($h, $args) = @_[HEAP, ARG0];
    my ($num, $color) = @$args;

    $h->{players}[$num]{color} = $color;
    $h->{players}[$num]{frame}->configure(-bg=>$color);
    $h->{players}[$num]{be_type}->configure(-bg=>$color);
    $h->{players}[$num]{but_color}->configure(
        -background => $color,
        -activebackground => $color);

    K->yield('_check_errors');
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

    #-- load images
    # FIXME: this should be in a sub/method somewhere
    my $path = find_installed(__PACKAGE__);
    my (undef, $dirname, undef) = fileparse($path);
    $h->{images}{paint} = $top->Photo(-file=>"$dirname/icons/paintbrush.png");

    # load icons
    # code & artwork taken from Tk::ToolBar
    $path = "$dirname/icons/tk_icons";
    open my $fh, '<', $path or die "can't open '$path': $!";
    while (<$fh>) {
        chomp;
        last if /^#/; # skip rest of file
        my ($n, $d) = (split /:/)[0, 4];
        $h->{images}{$n} = $top->Photo(-data => $d);
    }
	close $fh;

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
    $h->{button}{add_player} = $fpl->Button(
        -text    => 'New player...',
        -command => $s->postback('_but_new_player'),
    )->pack(@TOP,@FILLX);
    $h->{frame}{players} = $fpl;
    K->yield('_load_defaults');

    #-- bottom frame
    my $fbot = $top->Frame->pack(@BOTTOM, @FILLX, @PAD20);
    my $b_start = $h->{button}{start} = $fbot->Button(
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
# event: _but_color([$num])
#
# called when button to choose another color for player number $num has
# been clicked.
#
sub _ongui_but_color {
    my ($h, $s, $args) = @_[HEAP, SESSION, ARG0];

    my ($num) = @$args;
    my $top = $h->{toplevel};

    # creating popup window
    my $tc =$top->Menu;
    $tc->overrideredirect(1);  # no window decoration
    foreach my $i ( 0..$#COLORS ) {
        my $color = $COLORS[$i];
        my $row = $i < 5 ? 0 : 1;
        my $col = $i % 5;
        my $l = $tc->Label(
            -bg     => $color,
            -width  => 2,
        )->grid(-row=>$row, -column=>$col);
        $l->bind('<1>', $s->postback('_player_color', $num, $color));
    }

    # poping up
    $tc->Popup(
        -popover => $h->{players}[$num]{but_color},
        -overanchor => 'sw',
        -popanchor  => 'nw',
    );
    $top->bind('<1>', sub { $tc->destroy; $top->bind('<1>',undef); });
    #$tc->bind('<1>', sub { $tc->destroy; $top->bind('<1>',undef); });

    K->yield('_check_errors');
}


#
# event: _but_delete([$num])
#
# called when button to delete player number $num has been clicked.
#
sub _ongui_but_delete {
    my ($h, $s, $args) = @_[HEAP, SESSION, ARG0];

    # remove player
    my ($num) = @$args;
    $h->{players}[$num]{line}->destroy;
    delete $h->{players}[$num];

    # max players reached?
    K->yield('_check_nb_players');

    # check if we have enough players
    K->yield('_check_errors');
}


#
# event: _but_new_player()
#
# called when button to create a player has been clicked.
#
sub _ongui_but_new_player {
    my $h = $_[HEAP];

    my $players = $h->{players};
    my @players = grep { defined $_ } @$players;

    # pick a name
    my %names;
    @names{ @NAMES } = ();
    delete @names{ map { $_->{name} } @players };
    my $name = ( shuffle keys %names )[0];

    # pick a color
    my %colors;
    @colors{ @COLORS } = ();
    delete @colors{ map { $_->{color} } @players };
    my $color = ( shuffle keys %colors )[0];

    # default type
    my $type = 'Computer, hard';

    # create new player
    K->yield('_new_player', $name, $type, $color);
}


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

    # remove undef players from list of players. this can happen when
    # deleting some players: it is removed, but the list keeps an undef
    # value.
    my $players = $h->{players};
    my @players = grep { defined $_ } @$players;

    K->post('risk', 'new_game', { players => \@players } );
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

