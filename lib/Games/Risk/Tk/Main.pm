use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::Main;
# ABSTRACT: main prisk window

use Image::Size  qw{ imgsize };
use List::Util   qw{ min };
use MIME::Base64 qw{ encode_base64 };
use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use Readonly;
use Tk;
use Tk::Action;
use Tk::Balloon;
use Tk::Role::HasWidgets 1.112070; # _del_w
use Tk::ToolBar;

use Tk::HList;
use Tk::NoteBook;
use Tk::PNG;
use Tk::ROText;
use Tk::Sugar;

use Games::Risk::GUI::Startup;
use Games::Risk::I18n  qw{ T };
use Games::Risk::Point;
use Games::Risk::Utils qw{ $SHAREDIR };

with 'Tk::Role::HasWidgets';

Readonly my $K  => $poe_kernel;
Readonly my $mw => $poe_main_window; # already created by poe
Readonly my $WAIT_CLEAN_AI    => 1.000;
Readonly my $WAIT_CLEAN_HUMAN => 0.250;


# -- attributes

# a hash with all the actions.
has _actions => (
    ro,
    traits  => ['Hash'],
    isa     => 'HashRef[Tk::Action]',
    default => sub { {} },
    handles => {
        _set_action => 'set',
        _action     => 'get',
    },
);

# it's not usually a good idea to retain a reference on a poe session,
# since poe is already taking care of the references for us. however, we
# need the session to call ->postback() to set the various gui callbacks
# that will be fired upon gui events.
has _session => ( rw, weak_ref, isa=>'POE::Session' );

# zoom information
has _orig_bg_size => ( rw, isa=>'Games::Risk::Point' );
has _zoom         => ( rw, isa=>'Games::Risk::Point' );

# greyscale image
has _greyscale => ( rw, isa=>'Tk::Photo' );

# the strings that will appear in the status bar
has _status => (
    rw, isa=>'Str',
    trigger => sub {
        my ($self, $newtext) = @_;
        $self->_w('lab_status')->configure(-text=>$newtext);
    },
);
has _country_label => (
    rw, isa=>'Str',
    trigger => sub {
        my ($self, $newtext) = @_;
        $self->_w('country_label')->configure(-text=>$newtext);
    },
);

# the current map, player & selected country
has _curplayer => ( rw, isa=>'Games::Risk::Player',         clearer=>'_clear_curplayer' );
has _country   => ( rw, isa=>'Maybe[Games::Risk::Country]', clearer=>'_clear_country' );
has _map       => ( rw, isa=>'Games::Risk::Map',            clearer=>'_clear_map' );

# whether to re-attack automatically (do-or-die mode)
# FIXME: from config
has _auto_reattack => ( rw, isa=>'Bool', default=>0 );

# number of armies to be placed at beginning of game
has _armies        => ( rw, isa=>'HashRef', default=>sub { {} } );
has _armies_backup => ( rw, isa=>'HashRef', default=>sub { {} } );
has _armies_initial => (
    rw,
    isa     => 'Int',
    traits  => ['Counter'],
    default => 0,
    handles => {
        _armies_initial_dec => 'dec',
    },

);

# fake armies used to draw armies before sending to controller
has _fake_armies_in  => ( rw, isa=>'HashRef', default => sub{ {} } );
has _fake_armies_out => ( rw, isa=>'HashRef', default => sub{ {} } );


# -- initialization

#
# START()
#
# called as poe session initialization.
#
sub START {
    my ($self, $session) = @_[OBJECT, SESSION];
    $K->alias_set('main');
    $self->_set_session($session);
    $self->_build_gui;
}


# -- public events

event _default => sub {
    my ($sender, $event) = @_[SENDER, ARG0];
    return if $sender eq $poe_kernel;
    say $event;
};

{

=event attack_info

    attack_info( $src, $dst, \@attack, \@defence )

Give the result of C<$dst> attack from C<$src>: C<@attack> and
C<@defence> dices.

=cut

    event attack_info => sub {
        my ($self, $src, $dst, $attack, $defence) = @_[OBJECT, ARG0..$#_];

        # update status msg
        $self->_set_status( sprintf T('Attacking %s from %s'), $dst->name, $src->name );

        # update attack dices
        foreach my $i ( 1 .. 3 ) {
            my $d = $attack->[$i-1] // 0;
            my $img = $mw->Photo( -file => $SHAREDIR->file('images', "dice-$d.png") );
            $self->_w("lab_attack_$i")->configure(-image=>$img);
        }

        # update defence dices
        foreach my $i ( 1 .. 2 ) {
            my $d = $defence->[$i-1] // 0;
            my $img = $mw->Photo( -file => $SHAREDIR->file('images', "dice-$d.png") );
            $self->_w("lab_defence_$i")->configure(-image=>$img);
        }

        # draw a line on the canvas
        my $c = $self->_w('canvas');
        state $i = 0;
        my $zoomx = $self->_zoom->coordx; my $zoomy = $self->_zoom->coordy;
        my $x1 = $src->coordx * $zoomx; my $y1 = $src->coordy * $zoomy;
        my $x2 = $dst->coordx * $zoomx; my $y2 = $dst->coordy * $zoomy;
        $c->createLine(
            $x1, $y1, $x2, $y2,
            -arrow => 'last',
            -tags  => ['attack', "attack$i"],
            -fill  => 'yellow', #$self->_curplayer->color,
            -width => 4,
        );
        my $srcid = $src->id;
        $c->raise('attack', 'all');
        $c->raise("country$srcid", 'attack');
        $c->idletasks;
        my $wait = $self->_curplayer->type eq 'ai' ? $WAIT_CLEAN_AI : $WAIT_CLEAN_HUMAN;
        $K->delay_set(_clean_attack => $wait, $i);
        $i++;

        # update result labels
        my $nul = $mw->Photo( -file=> $SHAREDIR->file('icons', '16', 'empty.png') );
        my $r1 = $attack->[0] <= $defence->[0] ? 'actcross16' : 'actcheck16';
        my $r2 = scalar(@$attack) >= 2 && scalar(@$defence) == 2
            ? $attack->[1] <= $defence->[1] ? 'actcross16' : 'actcross16'
            : $nul;
        $self->_w('lab_result_1')->configure( -image => $r1 );
        $self->_w('lab_result_2')->configure( -image => $r2 );
    };


=event chnum

=event chown

    chnum( $country )
    chown( $country )

Force C<$country> to be redrawn: owner and number of armies.

=cut

    event chnum => \&_do_country_redraw;
    event chown => \&_do_country_redraw;
    event _country_redraw => \&_do_country_redraw;
    sub _do_country_redraw {
        my ($self, $country) = @_[OBJECT, ARG0];
        my $c = $self->_w('canvas');

        my $id    = $country->id;
        my $owner = $country->owner;
        my $fakein  = $self->_fake_armies_in->{$id}  // 0;
        my $fakeout = $self->_fake_armies_out->{$id} // 0;
        my $armies  = ($country->armies // 0) + $fakein - $fakeout;

        # change radius to reflect number of armies
        my ($radius, $fill_color, $text) = defined $owner
                ? (8, $owner->color, $armies)
                : (6,       'white', '');
        $radius += min(16,$armies-1)/2;

        my $zoom = $self->_zoom;
        my $x = $country->coordx * $zoom->coordx;
        my $y = $country->coordy * $zoom->coordy;
        my $x1 = $x - $radius; my $x2 = $x + $radius;
        my $y1 = $y - $radius; my $y2 = $y + $radius;

        # update canvas
        $c->delete( "country$id" );
        #  - circle
        $c->createOval(
            $x1, $y1, $x2, $y2,
            -fill    => $fill_color,
            -outline => 'black',
            -tags    => [ "country$id", 'circle' ],
        );

        #  - text
        $c->createText(
            $x, $y+1,
            -fill => 'white',
            -tags => [ "country$id", 'text' ],
            -text => $text,
        );

        $c->raise("country$id&&circle", 'all');
        $c->raise("country$id&&text",   'all');
    };


=event new_game

    new_game()

Received when the controller started a new game. Display the new map,
action & statusbar.

=cut

    event new_game => sub {
        my ($self, $args) = @_[OBJECT, ARG0];
        my $map = $args->{map};
        my $c = $self->_w('canvas');
        my $s = $self->_session;

        # add missing gui elements
        $self->_build_action_bar;
        $self->_build_player_bar;
        $self->_build_status_bar;
        Games::Risk::Tk::Cards->new({parent=>$mw});
        Games::Risk::Tk::Continents->new({parent=>$mw});
        Games::Risk::GUI::MoveArmies->spawn({parent=>$mw});

        # remove everything on the canvas
        $c->delete('all');
        $c->CanvasBind('<Configure>', undef);

        # prevent some actions
        $self->_action('new')->disable;
        $self->_action('close')->enable;
        $self->_action('show_cards')->enable;
        $self->_action('show_continents')->enable;

        # create background image
        # no need to actually display it: it will be done when canvas
        # will be reconfigured.
        my $bgpath = $map->background;
        my ($width, $height) = imgsize($bgpath);

        # store zoom information
        my $orig = Games::Risk::Point->new( { coordx=>$width, coordy=>$height } );
        my $zoom = Games::Risk::Point->new( { coordx=>1, coordy=>1 } );
        $self->_set_orig_bg_size( $orig );
        $self->_set_zoom( $zoom );

        # create capitals
        $K->yield('_country_redraw', $_) foreach $map->countries;

        # load greyscale image
        $self->_set_greyscale( $c->Photo(-file=>$map->greyscale) );

        # allow the canvas to update itself & reinstall callback.
        $c->idletasks;
        $c->CanvasBind('<Configure>', [$s->postback('_canvas_configure'), Ev('w'), Ev('h')] );

        # store map and say we're done
        $self->_set_map( $map );
        $K->post( risk => 'map_loaded' );
    };


=event place_armies

    place_armies( $nb [, $continent] )

Request user to place C<$nb> armies on her countries (maybe within
C<$continent> if supplied).

=cut

    event place_armies => sub {
        my ($self, $s, $nb, $continent) = @_[OBJECT, SESSION, ARG0, ARG1];

        my $name = defined $continent ? $continent->name : 'free';
        my $armies        = $self->_armies;
        my $armies_backup = $self->_armies_backup;
        $armies->{$name}        += $nb;
        $armies_backup->{$name} += $nb;   # to allow reinforcements redo

        # update the gui to reflect the new state.
        my $c = $self->_w('canvas');
        $c->CanvasBind( '<1>', $s->postback('_canvas_place_armies',  1) );
        $c->CanvasBind( '<3>', $s->postback('_canvas_place_armies', -1) );
        $c->CanvasBind( '<4>', $s->postback('_canvas_place_armies',  1) );
        $c->CanvasBind( '<5>', $s->postback('_canvas_place_armies', -1) );
        $self->_w('lab_step_place_armies')->configure( enabled );

        # update status msg
        my $count = 0;
        $count += $_ for values %$armies;
        $self->_set_status( sprintf T("%s armies left to place"), $count);
    };


=event place_armies_initial

    place_armies_initial()

Request user to place 1 armies on her countries. this is initial
reinforcement, so there's no limit on where to put the army, and armies
are put one by one.

=cut

    event place_armies_initial => sub {
        my ($self, $s) = @_[OBJECT, SESSION];
        my $c = $self->_w('canvas');
        $c->CanvasBind( '<1>', $s->postback('_canvas_place_armies_initial') );
    };


=event place_armies_initial_count

    place_armies_initial_count( $nb )

request user to place $nb armies on her countries. this is initial
armies placement:
    - no restriction on where
    - armies get placed one by one

this event just allows the gui to inform user how many armies will be
placed initially.

=cut

    event place_armies_initial_count => sub {
        my ($self, $nb) = @_[OBJECT, ARG0];
        $self->_set_status( sprintf T("%s armies left to place"), $nb );
        $self->_set_armies_initial( $nb );
    };


=event player_active

    player_active( $player )

Change player labels so that previous player is inactive, and new
active one is C<$player>.

=cut

    event player_active => sub {
        my ($self, $new) = @_[OBJECT, ARG0];

        my $old = $self->_curplayer;
        my $empty  = $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'empty.png') );
        my $active = $mw->Photo(-file=>$SHAREDIR->file('images', 'player-active.png') );
        $self->_w( "lab_player_".$old->name )->configure(-image=>$empty) if defined $old;
        $self->_w( "lab_player_".$new->name )->configure(-image=>$active);
        $self->_set_curplayer( $new );
    };


=event player_add

    player_add( $player )

Create a label for C<$player>, with tooltip information.

=cut

    event player_add => sub {
        my ($self, $player) = @_[OBJECT, ARG0];

        # create label
        my $f = $self->_w('fplayers');
        my $label = $f->Label(
            -bg    => $player->color,
            -image => $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'empty.png') ),
        )->pack(left);
        $self->_set_w( "lab_player_" . $player->name, $label );

        # associate tooltip
        my $tooltip = $player->name // '';
        given ($player->type) {
            when ('human') {
                $tooltip .= ' (' . T('human') . ')';
            }

            when ('ai') {
                my $ai = $player->ai;
                my $difficulty  = $ai->difficulty;
                my $description = $ai->description;
                $tooltip .= ' (' . sprintf(T('computer - %s'), $difficulty). ")\n$description";
            }

            default { $tooltip = '?'; }
        }
        $self->_w('tooltip')->attach($label, -msg=>$tooltip);
    };

}

# -- private events

{
    # event: _clean_attack( $i )
    # remove line corresponding to attack $i from canvas.
    event _clean_attack => sub {
        my ($self, $i) = @_[OBJECT, ARG0];
        $self->_w('canvas')->delete("attack$i");
    }

}

# -- actions

{
    # event: _about()
    # request about window to be shown.
    event _about => sub {
        require Games::Risk::Tk::About;
        Games::Risk::Tk::About->new( {parent=>$mw} );
    };

    # event: _close()
    # request to close current game.
    event _close => sub {
        my $self = shift;

        # warn controller that game is finished
        $K->post('risk', 'shutdown');

        # delete everything on canvas
        $self->_w('canvas')->delete('all');

        # delete ui widgets
        $self->_del_w('player_bar')->destroy;
        $self->_del_w('status_bar')->destroy;
        my $tb = $self->_del_w('tbactions');
        $tb->{CONTAINER}->packForget; # FIXME: breaking encapsulation
        $tb->destroy;

        # unstore data
        $self->_clear_country;
        $self->_clear_curplayer;
        $self->_clear_map;

        # enable / disable actions
        $self->_action('new')->enable;
        my @disable = qw{ close show_cards show_continents
            place_armies_redo place_armies_done attack_redo attack_done
            move_armies_done };
        $self->_action($_)->disable for @disable;
    };

    # event: _new()
    # request for a new game to be started.
    event _new => sub {
        Games::Risk::GUI::Startup->spawn;
    };

    # event: _help()
    # request help window to be shown.
    event _help => sub {
        require Games::Risk::Tk::Help;
        Games::Risk::Tk::Help->new( {parent=>$mw} );
    };

    # event: _place_armies_done()
    # called when all armies are placed correctly.
    event _place_armies_done => sub {
        my $self = shift;

        # check if we're done
        my $nb = 0;
        $nb += $_ for values %{ $self->_armies };
        if ( $nb != 0 ) {
            warn 'should not be there!';
            return;
        }

        # update gui
        $self->_set_status( '' );
        my $c = $self->_w('canvas');
        $c->CanvasBind('<1>', undef);
        $c->CanvasBind('<3>', undef);
        $c->CanvasBind('<4>', undef);
        $c->CanvasBind('<5>', undef);
        $self->_w('lab_step_place_armies')->configure(disabled);
        $self->_action( 'place_armies_redo' )->disable;
        $self->_action( 'place_armies_done' )->disable;

        # request controller to update
        my $fake_armies_in = $self->_fake_armies_in;
        foreach my $id ( keys %$fake_armies_in ) {
            next if $fake_armies_in->{$id} == 0; # don't send null reinforcements
            my $country = $self->_map->country_get($id);
            $K->post(risk => armies_placed => $country, $fake_armies_in->{$id});
        }
        $self->_set_armies        ( {} );
        $self->_set_armies_backup ( {} );
        $self->_set_fake_armies_in( {} );
    };

    # event: _place_armies_redo()
    # user wants to restart from scratch reinforcements placing.
    event _place_armies_redo => sub {
        my ($self, $s) = @_[OBJECT, SESSION];

        my $fake_armies_in = $self->_fake_armies_in;
        foreach my $id ( keys %$fake_armies_in ) {
            next if $fake_armies_in->{$id} == 0;
            delete $fake_armies_in->{$id};
            my $country = $self->_map->country_get($id);
            $K->yield('chnum', $country);
        }

        # forbid button next phase to be clicked
        $self->_action('place_armies_done')->disable;
        # allow adding armies
        $self->_w('canvas')->CanvasBind( '<1>', $s->postback('_canvas_place_armies', 1) );
        $self->_w('canvas')->CanvasBind( '<4>', $s->postback('_canvas_place_armies', 1) );

        # reset initials
        my $nb = 0;
        my $armies_backup = $self->_armies_backup;
        foreach my $k ( keys %$armies_backup ) {
            my $v = $armies_backup->{$k};
            $self->_armies->{$k} = $v; # restore initial value
            $nb += $v;
        }
        $self->_set_fake_armies_in( {} );

        # update status
        $self->_set_status( sprintf T("%s armies left to place"), $nb );
    };

    # event: _show_cards()
    # request card window to be shown/hidden.
    event _show_cards => sub {
        $K->post('cards', 'visibility_toggle');
    };

    # event: _show_continents()
    # request continents window to be shown/hidden.
    event _show_continents => sub {
        $K->post('continents', 'visibility_toggle');
    };


    # event: _quit()
    # request to quit the application.
    event _quit => sub {
        $mw->destroy;
    };
}

# -- gui events

{
    #
    # event: _canvas_configure( undef, [$canvas, $w, $h] );
    #
    # Called when canvas is reconfigured. new width and height available
    # with ($w, $h). note that reconfigure is also window motion.
    #
    event _canvas_configure => sub {
        my ($self, $args) = @_[OBJECT, ARG1];
        my ($c, $neww, $newh) = @$args;

        # check if we're at startup screen...
        my $map = Games::Risk->new->map;
        if ( defined $map ) {
            # in a game
            # create a new image resized to fit new dims
            my $magick = Image::Magick->new;
            $magick->Read( $self->_map->background );
            $magick->Scale(width=>$neww, height=>$newh);

            # install this new image inplace of previous background
            my $img = $c->Photo( -data => encode_base64( $magick->ImageToBlob ) );
            $c->delete('background');
            $c->createImage(0, 0, -anchor=>'nw', -image=>$img, -tags=>['background']);
            $c->lower('background', 'all');

            # update zoom factors. note that we don't want to resize greyscale
            # image since a) it takes time, which is unneeded since this image
            # is not displayed and b) greyscale are quite close from country to
            # country, and resizing will blur this to the point that it's no
            # longer usable. therefore, just storing a zoom factor and using it
            # will be enough for greyscale.
            my $zoom = $self->_zoom;
            my $orig = $self->_orig_bg_size;
            $zoom->set_coordx( $neww / $orig->coordx );
            $zoom->set_coordy( $newh / $orig->coordy );

            # force country redraw, for them to be correctly placed on the new
            # map.
            $K->yield('_country_redraw', $_) foreach $self->_map->countries;

        } else {
            # delete existing images
            $c->delete('startup');

            # create the initial welcome screen
            my @tags = ( -tags => ['startup'] );
            # first a background image...
            $c->createImage (
                $neww/2, $newh/2,
                -anchor => 'center',
                -image  => $mw->Photo( -file=>$SHAREDIR->file( "images", "splash.jpg") ),
                @tags,
            );
        }
    };


    #
    # event: _canvas_motion( undef, [$canvas, $x, $y] );
    #
    # Called when mouse is moving over the $canvas at coords ($x,$y).
    #
    event _canvas_motion => sub {
        my ($self, $args) = @_[OBJECT, ARG1];

        my (undef, $x,$y) = @$args; # first param is canvas

        # correct with zoom factor
        my $zoom = $self->_zoom;
        $x /= defined($zoom) ? $zoom->coordx : 1;
        $y /= defined($zoom) ? $zoom->coordy : 1;

        # get greyscale pointed by mouse, this may die if moving too fast
        # outside of the canvas. we just need the 'red' component, since
        # green and blue will be the same.
        my $grey = 0;
        eval { ($grey) = $self->_greyscale->get($x,$y) };
        return unless defined $self->_map;
        my $country    = $self->_map->country_get($grey);

        # update country and country label
        $self->_set_country( $country ); # may be undef
        $self->_set_country_label( defined $country
            ? join(' - ', $country->continent->name, $country->name)
            : '' );
    };


    #
    # event: _canvas_place_armies( [ $diff ] );
    #
    # Called when mouse click on the canvas during armies placement.
    # Update "fake armies" to place $diff (may be negative) army on the
    # current country.
    #
    event _canvas_place_armies => sub {
        my ($self, $s, $args) = @_[OBJECT, SESSION, ARG0];

        my $curplayer = $self->_curplayer;
        my $country   = $self->_country;
        return unless defined $country;
        my $id        = $country->id;
        my ($diff)    = @$args;

        # checks...
        return if $country->owner->name ne $curplayer->name; # country owner
        return if $diff + ($self->_fake_armies_in->{$id}//0) < 0;   # negative count (free army move! :-) )

        # update armies count
        my $name   = $country->continent->name;
        my $armies = $self->_armies;
        if ( exists $armies->{$name} ) {
            $armies->{$name} -= $diff;
            # FIXME: check if possible, otherwise default to free
        } else {
            $armies->{free} -= $diff;
            # FIXME: check if possible
        }

        # redraw country.
        $self->_fake_armies_in->{ $country->id } += $diff;
        $K->yield( 'chnum', $country );

        # allow redo button
        $self->_action('place_armies_redo')->enable;

        # check if we're done
        my $nb = 0;
        my $c  = $self->_w('canvas');
        $nb += $_ for values %$armies;
        $self->_set_status( sprintf T("%s armies left to place"), $nb );
        if ( $nb == 0 ) {
            # allow button next phase to be clicked
            $self->_action('place_armies_done')->enable;
            # forbid adding armies
            $c->CanvasBind('<1>', undef);
            $c->CanvasBind('<4>', undef);

        } else {
            # forbid button next phase to be clicked
            $self->_action('place_armies_done')->disable;
            # allow adding armies
            $c->CanvasBind( '<1>', $s->postback('_canvas_place_armies', 1) );
            $c->CanvasBind( '<4>', $s->postback('_canvas_place_armies', 1) );
        }
    };


    #
    # event: _canvas_place_armies_initial();
    #
    # Called when mouse click on the canvas during initial armies placement.
    # Will request controller to place one army on the current country.
    #
    event _canvas_place_armies_initial => sub {
        my $self = shift;

        my $curplayer = $self->_curplayer;
        my $country   = $self->_country;

        # check country owner
        return unless defined $country;
        return if $country->owner->name ne $curplayer->name;

        # change canvas bindings
        $self->_w('canvas')->CanvasBind('<1>', undef);

        # update gui
        $self->_armies_initial_dec;
        my $nb = $self->_armies_initial;
        $self->_set_status( $nb ? sprintf( T("%s armies left to place"), $nb) : '' );

        # tell controller that we've placed an army. controller will then
        # ask us to redraw the country.
        $K->post(risk => initial_armies_placed => $country, 1);
    };


}


# -- gui creation

{

    #
    # $main->_build_gui;
    #
    # create the various gui elements.
    #
    sub _build_gui {
        my $self = shift;
        my $s = $self->_session;

        # hide window during its creation to avoid flickering
        $mw->withdraw;

        # prettyfying tk app.
        # see http://www.perltk.org/index.php?option=com_content&task=view&id=43&Itemid=37
        $mw->optionAdd('*BorderWidth' => 1);

        # set windowtitle
        $mw->title('prisk');
        my $icon = $SHAREDIR->file('icons', '32', 'prisk.png');
        my $mask = $SHAREDIR->file('icons', '32', 'prisk-mask.xbm');
        $mw->iconimage( $mw->Photo( -file=>$icon ) );
        $mw->iconmask ( '@' . $mask );

        # make sure window is big enough
        #my $config = Games::Pandemic::Config->instance;
        #my $width  = $config->get( 'win_width' );
        #my $height = $config->get( 'win_height' );
        #$mw->geometry($width . 'x' . $height);

        # create the actions
        my @enabled  = qw{ new quit help about };
        my @disabled = qw{ close show_cards show_continents
            place_armies_redo place_armies_done attack_redo attack_done
            move_armies_done };
        foreach my $what ( @enabled, @disabled ) {
            my $action = Tk::Action->new(
                window   => $mw,
                callback => $s->postback("_$what"),
            );
            $self->_set_action($what, $action);
        }

        # allow some actions
        $self->_action($_)->enable  for @enabled;
        $self->_action($_)->disable for @disabled;

        # the tooltip
        $self->_set_w('tooltip', $mw->Balloon);

        # WARNING: we need to create the toolbar object before anything
        # else. indeed, tk::toolbar loads the embedded icons in classinit,
        # that is when the first object of the class is created - and not
        # during compile time.
        $self->_build_toolbar;
        $self->_build_menubar;
        $self->_build_canvas;

        # center & show the window
        # FIXME: restore last position saved?
        $mw->Popup;
        $mw->packPropagate(0); # prevent main window from being resized by other widgets
        $mw->minsize($mw->width, $mw->height);
    }

    #
    # $main->_build_action_bar;
    #
    # create the action bar at the top of the window, with the various
    # action buttons that a player can press when it's her turn.
    #
    sub _build_action_bar {
        my $self = shift;
        my $session = $self->_session;

        # create the toolbar
        my $tbmain = $self->_w('toolbar');
        my $tb = $mw->ToolBar(-movable => 0, -in=>$tbmain );
        $self->_set_w('tbactions', $tb);

        # the toolbar widgets
        my @actions = (
        [ T('Game state: ')                                          ],
        [ T('place armies'),     'lab_step_place_armies'             ],
        [ T('undo all'),         'place_armies_redo', 'actreload22'  ],
        [ T('ready for attack'), 'place_armies_done', 'navforward22' ],
        [ T('attack'),           'lab_step_attack'                   ],
        [ T('attack again'),     'attack_redo',       'actredo22'    ],
        [ T('consolidate'),      'attack_done',       'navforward22' ],
        [ T('move armies'),      'lab_step_move_armies'              ],
        [ T('turn finished'),    'move_armies_done',  'playstop22'   ],
        );

        # create the widgets
        foreach my $item ( @actions ) {
            my ($label, $action, $icon) = @$item;

            if ( defined $icon ) {
                # regular toolbar widgets
                my $widget = $tb->Button(
                    -image       => $icon,
                    -tip         => $label,
                    -command     => $session->postback( "_action_$action" ),
                );
                $self->_action($action)->add_widget($widget);
                next;
            }

            # label
            my $widget = $tb->Label( -text => $label );
            next unless $action;
            $widget->configure( disabled );
            $self->_set_w( $action => $widget );
        }
    }

    #
    # $main->_build_menubar;
    #
    # create the window's menu.
    #
    sub _build_menubar {
        my $self = shift;
        my $s = $self->_session;

        # no tear-off menus
        $mw->optionAdd('*tearOff', 'false');

        my $menubar = $mw->Menu;
        $mw->configure(-menu => $menubar );
        $self->_set_w('menubar', $menubar);

        # menu game
        my @mnu_game = (
        [ 'new',   'filenew16',   'Ctrl+N', T('~New game')   ],
        #[ 'load',  'fileopen16',  'Ctrl+O', T('~Load game')  ],
        [ 'close', 'fileclose16', 'Ctrl+W', T('~Close game') ],
        [ '---'                                              ],
        [ 'quit',  'actexit16',   'Ctrl+Q', T('~Quit')       ],
        );
        $self->_build_menu('game', T('~Game'), @mnu_game);

        # menu view
        my @mnu_view = (
        [ 'show_cards',      $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'cards.png')), 'F5', T('~Cards') ],
        [ 'show_continents', $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'continents.png')), 'F6', T('C~ontinents') ],
        );
        $self->_build_menu('view', T('~View'), @mnu_view);

        # menu actions
        my @mnu_actions = (
        [ 'place_armies_redo', 'actreload16',  'u', T('~Undo all') ],
        [ 'place_armies_done', 'navforward16', 'a', T('~Attack') ],
        [ 'attack_redo',       'actredo16',    'r', T('~Re-attack') ],
        [ 'attack_done',       'navforward16', 'c', T('~Consolidate') ],
        [ 'move_armies_done',  'playstop16',   'f', T('~Finish turn') ],
        );
        $self->_build_menu('actions', T('~Actions'), @mnu_actions);

        # menu help
        my @mnu_help = (
        [ 'help',  $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'help.png')), 'F1', T('~Help') ],
        [ 'about', $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'about.png')),  '', T('About') ],
        );
        $self->_build_menu('help', T('~Help'), @mnu_help);
    }

    #
    # $self->_build_menu( $mnuname, $mnulabel, @submenus );
    #
    # Create the menu $label, with all the @submenus.
    # @submenus is a list of [$name, $icon, $accel, $label] items.
    # Store the menu items under the name menu_$mnuname_$name.
    #
    sub _build_menu {
        my ($self, $mnuname, $mnulabel, @submenus) = @_;
        my $menubar = $self->_w('menubar');
        my $s = $self->_session;

        my $menu = $menubar->cascade(-label => $mnulabel);
        foreach my $item ( @submenus ) {
            my ($name, $icon, $accel, $label) = @$item;

            # separators are easier
            if ( $name eq '---' ) {
                $menu->separator;
                next;
            }

            # regular buttons
            my $action = $self->_action($name);
            my $widget = $menu->command(
                -label       => $label,
                -image       => $icon,
                -compound    => 'left',
                -accelerator => $accel,
                -command     => $action->callback,
            );
            $self->_set_w("menu_${mnuname}_${name}", $widget);

            # create the bindings. note: we also need to bind the lowercase
            # letter too!
            $action->add_widget($widget);
            if ( $accel ) {
                $accel =~ s/Ctrl\+/Control-/;
                $action->add_binding("<$accel>");
                $accel =~ s/Control-(\w)/"Control-" . lc($1)/e;
                $action->add_binding("<$accel>");
            }
        }
    }

    #
    # $main->_build_player_bar;
    #
    # create the player bar at the right of the window.
    #
    sub _build_player_bar {
        my $self = shift;
        my $s    = $self->_session;

        my $fright = $mw->Frame->pack(right, fill2, -before=>$self->_w('canvas'));
        $self->_set_w( player_bar => $fright );

        #-- players frame
        my $fpl = $fright->Frame->pack(top);
        $fpl->Label(-text=>T('Players'))->pack(top);
        my $fplist = $fpl->Frame->pack(top);
        $self->_set_w( fplayers => $fplist );

        #-- dices frame
        my $dice0   = $mw->Photo(-file=>$SHAREDIR->file('images', 'dice-0.png') );
        my $empty16 = $mw->Photo(-file=>$SHAREDIR->file('icons', '16', 'empty.png') );
        my $fdice = $fright->Frame->pack(top,fillx,pady(10));
        $fdice->Label(-text=>T('Dice arena'))->pack(top,fillx);
        my $fd1 = $fdice->Frame->pack(top,fill2);
        my $a1 = $fd1->Label(-image=>$dice0)->pack(left);
        my $a2 = $fd1->Label(-image=>$dice0)->pack(left);
        my $a3 = $fd1->Label(-image=>$dice0)->pack(left);
        my $fr = $fdice->Frame->pack(top,fill2);
        my $r1 = $fr->Label( -image=>$empty16, -width=>38)->pack(left);
        my $r2 = $fr->Label( -image=>$empty16, -width=>38)->pack(left);
        my $fd2 = $fdice->Frame->pack(top,fill2);
        my $d1 = $fd2->Label(-image=>$dice0)->pack(left);
        my $d2 = $fd2->Label(-image=>$dice0)->pack(left);
        $self->_set_w( lab_attack_1  => $a1 );
        $self->_set_w( lab_attack_2  => $a2 );
        $self->_set_w( lab_attack_3  => $a3 );
        $self->_set_w( lab_result_1  => $r1 );
        $self->_set_w( lab_result_2  => $r2 );
        $self->_set_w( lab_defence_1 => $d1 );
        $self->_set_w( lab_defence_2 => $d2 );

        #-- redo checkbox
        my $cb_reattack = $fright->Checkbutton(
            -text     => T('Auto-reattack'),
            -anchor   => 'w',
        )->pack(top,fillx);
        $cb_reattack->select if $self->_auto_reattack;
        $self->_w('tooltip')->attach($cb_reattack, -msg=>T('Automatically re-do last attack if attacker still has more than 3 armies'));
    }

    #
    # $main->_build_status_bar;
    #
    # create the status bar at the bottom of the window.
    #
    sub _build_status_bar {
        my $self = shift;

        # the status bar
        my $fbot   = $mw->Frame->pack(bottom, fillx, -before=>$self->_w('canvas'));
        $self->_set_w( status_bar => $fbot );

        # label to display status
        my $status = $fbot->Label( -anchor =>'w' )->pack(left,xfillx, pad1);
        $self->_set_w( lab_status => $status );

        # label to display country pointed by mouse
        my $clabel = $fbot->Label( -anchor => 'e' )->pack(right, xfillx, pad1);
        $self->_set_w( country_label => $clabel );
    }

    #
    # $main->_build_toolbar;
    #
    # create the window toolbar (the one just below the menu).
    #
    sub _build_toolbar {
        my $self = shift;
        my $session = $self->_session;

        # create the toolbar
        my $tb = $mw->ToolBar( -movable => 0, top );
        $self->_set_w('toolbar', $tb);

        # the toolbar widgets
        my @tb = (
            [ 'Button', 'filenew22',   'new',   T('New game')   ],
            #[ 'Button', 'fileopen22',  'load',  T('Load game')  ],
            [ 'Button', 'fileclose22', 'close', T('Close game') ],
            [ 'Button', 'actexit22',   'quit',  T('Quit')       ],
        );

        # create the widgets
        foreach my $item ( @tb ) {
            my ($type, $image, $name, $tip) = @$item;

            # separator is a special case
            $tb->separator( -movable => 0 ), next if $type eq 'separator';
            my $action = $self->_action($name);

            # regular toolbar widgets
            my $widget = $tb->$type(
                -image       => $image,
                -tip         => $tip,
                -command     => $action->callback,
            );
            $self->_set_w( "tbut_$name", $widget );
            $action->add_widget( $widget );
        }
    }

    #
    # $main->_build_canvas;
    #
    # create the canvas, where the map will be drawn and the action
    # take place.
    #
    sub _build_canvas {
        my $self = shift;
        my $s = $self->_session;

        # FIXME: the following needs to be changed according to config /
        # latest values
        my $width  = 820;
        my $height = 425;

        # creating the canvas
        my $c  = $mw->Canvas(-width=>$width,-height=>$height)->pack(top, xfill2);
        $self->_set_w('canvas', $c);

        # removing class bindings
        foreach my $button ( qw{ 4 5 6 7 } ) {
            $mw->bind('Tk::Canvas', "<Button-$button>",       undef);
            $mw->bind('Tk::Canvas', "<Shift-Button-$button>", undef);
        }
        foreach my $key ( qw{ Down End Home Left Next Prior Right Up } ) {
            $mw->bind('Tk::Canvas', "<Key-$key>", undef);
            $mw->bind('Tk::Canvas', "<Control-Key-$key>", undef);
        }

        # initial actions
        $c->CanvasBind('<Configure>', [$s->postback('_canvas_configure'), Ev('w'), Ev('h')] );
        $c->CanvasBind( '<Motion>',   [$s->postback('_canvas_motion'),    Ev('x'), Ev('y')] );
    }

}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    START


=head1 DESCRIPTION

This class implements the whole L<Tk> graphical interface. It is a POE
session driving events, reacting to user interaction & updating the
display as game changes status.
