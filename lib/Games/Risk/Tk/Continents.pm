use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::Continents;
# ABSTRACT: continents information

use Moose;
use MooseX::Has::Sugar;
use POE                    qw{ Loop::Tk };
use MooseX::POE;
use Readonly;
use Tk;
use Tk::Sugar;

use Games::Risk::I18N      qw{ T };
use Games::Risk::Resources qw{ image $SHAREDIR };

Readonly my $K => $poe_kernel;


# -- attributes

=attr parent

A L<Tk> window that will be the parent of the toplevel window created.
This parameter is mandatory.

=cut

has parent    => ( ro, required, weak_ref, isa=>'Tk::Widget' );
has _toplevel => ( rw, lazy_build, isa=>'Tk::Toplevel' );


# -- initialization / finalization

sub _build__toplevel {
    my $self = shift;
    return $self->parent->Toplevel;
}


#
# session initialization.
#
sub START {
    my ($self, $s) = @_[OBJECT, SESSION];

    $K->alias_set('continents');

    #-- create gui

    my $top = $self->_toplevel;
    $top->withdraw;           # window is hidden first
    $top->title( T('Continents') );
    my $icon = $SHAREDIR->file('icons', '32', 'continents.png');
    my $mask = $SHAREDIR->file('icons', '32', 'continents-mask.xbm');
    $top->iconimage( $top->Photo(-file=>$icon) );
    $top->iconmask( '@' . $mask );

    #- populate continents list
    my $map = Games::Risk->new->map;
    my @continents =
        sort {
             $b->bonus <=> $a->bonus ||
             $a->name  cmp $b->name
        }
        $map->continents;
    my $row = 0;
    foreach my $c ( @continents ) {
        $top->Label(-text=>$c->name
        )->grid(-row=>$row,-column=>0,-sticky=>'w');
        $top->Label(-text=>$c->bonus)->grid(-row=>$row,-column=>1);
        $row++;
    }

    #- force window geometry
    $top->update;    # force redraw
    $top->resizable(0,0);

    #-- trap some events
    $top->protocol( WM_DELETE_WINDOW => $s->postback('visibility_toggle'));
    $top->bind('<F6>', $s->postback('visibility_toggle'));
}


#
# session destruction.
#
sub STOP {
    warn "gui-continents shutdown\n";
}


# -- public events

=method shutdown

    $K->post( gui-continents => 'shutdown' );

Kill current session. The toplevel window has already been destroyed.

=cut

event shutdown => sub {
    $K->alias_remove('continents');
};


=method visibility_toggle

    $K->post( gui-continents => 'visibility_toggle' );

Request window to be hidden / shown depending on its previous state.

=cut

event visibility_toggle => sub {
    my $self = shift;

    my $top = $self->_toplevel;
    my $method = ($top->state eq 'normal') ? 'withdraw' : 'deiconify'; # parens needed for xgettext
    $top->$method;
};

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage      START STOP

=head1 SYNOPSYS

    Games::Risk::Tk::Continents->new(%opts);


=head1 DESCRIPTION

C<GR::Tk::Continents> implements a POE session, creating a Tk window to
list the continents of the map and their associated bonus.

The methods are in fact the events accepted by the session.


