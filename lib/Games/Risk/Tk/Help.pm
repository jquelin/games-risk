use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::Help;
# ABSTRACT: prisk manual window

use Moose;
use Path::Class;
use Tk::Pod::Text;
use Tk::Role::Dialog 1.101480;
use Tk::Sugar;

use Games::Risk::I18n  qw{ T };
use Games::Risk::Utils qw{ $SHAREDIR };

with 'Tk::Role::Dialog';


# -- initialization / finalization

sub _build_title     { 'prisk - ' . T('help') }
sub _build_icon      { $SHAREDIR->file('icons', '32','help.png') }
sub _build_header    { T('How to play?') }
sub _build_resizable { 1 }
sub _build_cancel    { T('Close') }


# -- private subs

#
# $self->_build_gui( $frame );
#
# called by tk::role::dialog to build the inner dialog
#
sub _build_gui {
    my ($self,$f) = @_;

    $f->PodText(
        -file       => $SHAREDIR->file('manual.pod'),
        -scrollbars => 'e',
    )->pack( top, xfill2, pad10 );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 DESCRIPTION

C<GR::Tk::Help> implements a Tk window used to show the manual of the
game. The manual itself is in a pod file in the share directory.


=attr parent

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.

=method new

    Games::Risk::Tk::Help->new( %opts );

Create a window showing some basic help about the game. See the
attributes for available options.

