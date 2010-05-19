use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::Help;
# ABSTRACT: prisk manual window

use File::ShareDir qw{ dist_dir };
use Moose;
use Path::Class;
use Tk::Pod::Text;
use Tk::Sugar;

use Games::Risk::I18N qw{ T };

with 'Tk::Role::Dialog';


# -- initialization / finalization

sub _build_title     { 'prisk - help' }
#sub _build_icon      { '/home/jquelin/prog/games-risk/share/images/card-artillery.png' }
sub _build_header    { 'How to play?' }
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
        -file       => file( dist_dir('Games-Risk'),'manual.pod' ),
        -scrollbars => 'e',
    )->pack( top, xfill2, pad10 );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 DESCRIPTION

C<GR::GUI::Help> implements a Tk window used to show the manual of the
game. The manual itself is in a pod file in the share directory.


=attr parent

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.

=method new

    Games::Risk::Tk::Help->new( %opts );

Create a window showing some basic help about the game. See the
attributes for available options.

