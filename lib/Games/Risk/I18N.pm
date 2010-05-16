use 5.010;
use strict;
use warnings;

package Games::Risk::I18N;
# ABSTRACT: game internationalization

use Encode;
use Locale::TextDomain 'Games-Risk';
use Sub::Exporter -setup => { exports => [ qw{ T } ] };


# -- public subs

=method my $locstr = T( $string );

Performs a call to C<gettext> on C<$string>, convert it from utf8 and
return the result.

=cut

sub T { return decode('utf8', __($_[0])); }

1;
__END__

=head1 SYNOPSIS

    use Games::Risk::I18N;
    say T('message');


=head1 DESCRIPTION

This module handles the game's internationalization (i18n). It is using
C<Locale::TextDomain> underneath, so refer to this module's documentation
for more information.

