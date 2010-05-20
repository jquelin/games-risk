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

with 'Tk::Role::Dialog';


Readonly my $K => $poe_kernel;


# -- initialization / finalization

sub _build_title     { 'prisk - ' . T('continents') }
sub _build_icon      { $SHAREDIR->file('icons', '32','continents.png')->stringify }
sub _build_header    { T('Continents information') }
sub _build_resizable { 1 }
sub _build_ok        { T('Close') }


#
# session initialization.
#
sub START {
    my ($self, $s) = @_[OBJECT, SESSION];
    $K->alias_set('continents');

    #-- trap some events
    my $top = $self->_toplevel;
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


# -- private methods

#
# $self->_valid;
#
# called by tk:role:dialog to build the inner dialog.
#
sub _build_gui {
    my ($self, $f) = @_;

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
        $f->Label(-text=>$c->name
        )->grid(-row=>$row,-column=>0,-sticky=>'w');
        $f->Label(-text=>$c->bonus)->grid(-row=>$row,-column=>1);
        $row++;
    }
}


#
# $self->_valid;
#
# called by tk:role:dialog when user click the ok button.
#
sub _valid {
    my $self = shift;
    $self->yield( 'visibility_toggle' );
}

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


=attr parent

A L<Tk> window that will be the parent of the toplevel window created.
This parameter is mandatory.

=cut
