#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Heap;

use 5.010;
use strict;
use warnings;

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ map players } );



1;

__END__



=head1 NAME

Games::Risk::Heap - poe session heap for Games::Risk 



=head1 SYNOPSIS

    POE::Session->create(
        [...]
        heap => Games::Risk::Heap->new,
        [...]
    );



=head1 DESCRIPTION

This module implements a heap object, to be used in C<Games::Risk> POE
session. Furthermore, the non-event driven part of C<Games::Risk> will
be implemented as methods in this module.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $heap = Games::Risk::Heap->new

Create a new heap. No params needed.


=back


=head2 Accessors

The following accessors (acting as mutators, ie getters and setters) are
available for C<Games::Risk::Heap> objects:


=over 4

=item * map()

the current C<Games::Risk::Map> object of the game.


=item * players()

the C<Games::Risk::Player> objects of the current game.

=back


=head2 Public methods

=over 4


=back



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

