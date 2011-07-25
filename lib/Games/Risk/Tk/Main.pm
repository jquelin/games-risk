use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::Main;
# ABSTRACT: main prisk window

use Moose;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use Readonly;
use Tk;
use Tk::Action;
use Tk::Balloon;
use Tk::ToolBar;

use List::Util qw{ first };
use Tk::HList;
use Tk::NoteBook;
use Tk::PNG;
use Tk::ROText;
use Tk::Sugar;

use Games::Risk::I18n  qw{ T };
use Games::Risk::Utils qw{ $SHAREDIR };

with 'Tk::Role::HasWidgets';

Readonly my $K  => $poe_kernel;
Readonly my $mw => $poe_main_window; # already created by poe


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


# -- gui events

{
    #
    # event: _canvas_configure( undef, [$canvas, $w, $h] );
    #
    # Called when canvas is reconfigured. new width and height available
    # with ($w, $h). note that reconfigure is also window motion.
    #
    event _canvas_configure => sub {
        my ($self, $args) = @_[HEAP, ARG1];
        my ($c, $neww, $newh) = @$args;

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
        my @enabled  = qw{ new quit };
        my @disabled = qw{ close show_cards show_continents };
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
        $mw->minsize($mw->width, $mw->height);
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
        [ 'show_cards',      '', 'F5', T('~Cards') ],
        [ 'show_continents', '', 'F6', T('C~ontinents') ],
        );
        $self->_build_menu('view', T('~View'), @mnu_view);
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
            $accel =~ s/Ctrl\+/Control-/;
            $action->add_binding("<$accel>");
            $accel =~ s/Control-(\w)/"Control-" . lc($1)/e;
            $action->add_binding("<$accel>");
        }
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
        my $width  = 677;
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
session driving events and updating the display as workers change
status.
