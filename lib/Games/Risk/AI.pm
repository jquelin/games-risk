#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::AI;

use 5.010;
use strict;
use warnings;

use base qw{ Class::Accessor::Fast };


sub description {
    my ($self) = @_;
    my $descr = $self->_description;
    $descr =~ s/[\n\s]+\z//;
    $descr =~ s/\A\n+//;
    return $descr;
}


1;

__END__



=head1 NAME

Games::Risk::AI - base class for all ais



=head1 SYNOPSIS

    [don't use this class directly]



=head1 DESCRIPTION

This module is the base class for all artificial intelligence.



=head1 METHODS

=head2 Object methods

An AI object will typically implements the following methods:


=over 4

=item * my $str = $ai->description()

Return a short description of the ai and how it works.


=item * my $str = $ai->difficulty()

Return a difficulty level for the ai.


=back

Note that some of those methods may be inherited from the base class, when it
provide sane defaults.



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

