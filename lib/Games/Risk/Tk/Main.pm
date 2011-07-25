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

use List::Util qw{ first };
use Tk::HList;
use Tk::NoteBook;
use Tk::PNG;
use Tk::ROText;
use Tk::Sugar;

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



{ # -- gui creation

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
        my @disabled = qw{ close };
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

    sub _build_toolbar {}
    sub _build_menubar {}
    sub _build_canvas {}
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
