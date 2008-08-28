#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::Player;

use strict;
use warnings;

use Readonly;

Readonly my @COLORS => (
    '#333333',  # grey20
    '#FE6F5E',  # bittersweet
    '#FFFF99',  # canary 
    '#1560BD',  # denim 
    '#5FA777',  # forest green 
    '#FBAED2',  # lavender 
    '#FFCBA4',  # peach 
    '#00CCCC',  # robin's egg blue 
    '#9E5B40',  # sepia 
);
my $Color => 0;


use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ color } );


sub new {
    my ($pkg, $args) = @_;

    my $self = bless {}, $pkg;
    $self->color( $COLORS[ $Color++ ] );
    # FIXME: what if beyond sepia
}



1;

__END__



=head1 NAME

Games::Risk::Player - risk player



=head1 SYNOPSIS

    my $id = Games::Risk::Player->new(\%params);



=head1 DESCRIPTION




=head1 METHODS



=head1 EVENTS RECEIVED



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

