#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::GUI::Constants;

use strict;
use warnings;

use base qw{ Exporter };

our @EXPORT = qw{
    @TOP @BOTTOM @LEFT @RIGHT
    @FILLX  @FILL2
    @XFILLX @XFILL2
    @PAD1   @PAD20
    @ENON   @ENOFF
};

# pack sides
our @TOP     = ( -side => 'top'    );
our @BOTTOM  = ( -side => 'bottom' );
our @LEFT    = ( -side => 'left'   );
our @RIGHT   = ( -side => 'right'  );

# pack fill / expand
our @FILLX   = ( -fill => 'x'    );
our @FILL2   = ( -fill => 'both' );
our @XFILLX  = ( -expand => 1, -fill => 'x'    );
our @XFILL2  = ( -expand => 1, -fill => 'both' );

# padding
our @PAD1    = ( -padx => 1, -pady => 1);
our @PAD20   = ( -padx => 20, -pady => 20);

# enabled state
our @ENON    = ( -state => 'normal' );
our @ENOFF   = ( -state => 'disabled' );



1;

__END__


=head1 NAME

Games::Risk::GUI::Constants - tk constants



=head1 SYNOPSYS

    use Games::Risk::GUI::Constants;
    $mw->Frame->pack(@LEFT);



=head1 DESCRIPTION

This module just exports easy to use constants for tk, such as C<@TOP>
to be used in place of C<-side => 'top'>. Since those are quite common,
it's easier to use those constants.

Other than that, the module does nothing.



=head1 SEE ALSO

L<Games::Risk>, L<Tk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

