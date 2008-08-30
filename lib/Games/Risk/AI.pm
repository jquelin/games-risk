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

use Carp;
use List::Util qw{ shuffle };
use Readonly;

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ player } );

my @NAMES = shuffle (
    'Napoleon',             # france,   1769  - 1821
    'Staline',              # russia,   1878  - 1953
    'Alexander the Great',  # greece,   356BC - 323BC
    'Julius Caesar',        # rome,     100BC - 44BC
    'Attila',               # hun,      406   - 453
    'Genghis Kahn',         # mongolia, 1162  - 1227
    'Charlemagne',          # france,   747   - 814
    'Saladin',              # iraq,     1137  - 1193
);
my $Id_name = 0;


#--
# CLASS METHODS

# -- constructor

#
# my $ai = Games::Risk::AI::$AItype->new( \%params );
#
# Note that you should not instantiate a Games::Risk::AI object directly:
# instantiate an AI subclass.
#
# Create a new AI of type $AItype. All subclasses accept the following
# parameters:
#  - player: the Game::Risk::Player associated to the AI. (mandatory)
#
# Note that the AI will automatically get a name, and update the player object.
#
sub new {
    my ($pkg, $args) = @_;

    # assign a new color
    my $nbnames = scalar(@NAMES);
    croak "can't assign more than $nbnames names" if $Id_name >= $nbnames;
    my $name = $NAMES[ $Id_name++ ];

    # create the object
    my $self = bless $args, $pkg;

    # update other object attributes
    $self->player->name( $name );

    return $self;
}


#--
# METHODS

# -- public methods

#
# my $str = $ai->description;
#
# Format the subclass description.
#
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

=head2 Constructor


Note that you should not instantiate a C<Games::Risk::AI> object directly:
instantiate an AI subclass.


=over 4

=item * my $ai = Games::Risk::AI::$AItype->new( \%params )

Create a new AI of type C<$AItype>. All subclasses accept the following parameters:

=over 4

=item * player: the C<Game::Risk::Player> associated to the AI. (mandatory)

=back


Note that the AI will automatically get a name, and update the player object.


=back


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

