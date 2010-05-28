use 5.010;
use strict;
use warnings;

package Games::Risk::Tk::About;
# ABSTRACT: prisk about information

use Moose;
use Path::Class;

use Games::Risk;
use Games::Risk::I18N      qw{ T };
use Games::Risk::Resources qw{ $SHAREDIR };

with 'Tk::Role::Dialog';


# -- initialization / finalization

sub _build_title     { 'prisk - ' . T('about') }
sub _build_icon      { $SHAREDIR->file('icons', '32', 'about.png') }
sub _build_header    { "prisk $Games::Risk::VERSION" }
sub _build_resizable { 0 }
sub _build_cancel    { T('Close') }

sub _build_text { join "\n",
    T('Created by Jerome Quelin'),
    T('Copyright (c) 2008 Jerome Quelin, all rights reserved'),
    '',
    T('prisk is free software; you can redistribute it and/or modify it under the terms of the GPLv3.'),
    ;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 DESCRIPTION

C<GR::Tk::About> implements a Tk window used to show the copyright and
licence of the game.


=attr parent

A Tk window that will be the parent of the toplevel window created. This
parameter is mandatory.

=method new

    Games::Risk::Tk::About->new( %opts );

Create a window showing some information about the game. See the
attributes for available options.

