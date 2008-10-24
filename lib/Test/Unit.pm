=head1 NAME

Test::Unit - the PerlUnit testing framework

=head1 SYNOPSIS

This package provides only the project version number, copyright
texts, and a framework overview in POD format.

=head1 DESCRIPTION

This framework is intended to support unit testing in an
object-oriented development paradigm (with support for
inheritance of tests etc.) and is derived from the JUnit
testing framework for Java by Kent Beck and Erich Gamma.  To
start learning how to use this framework, see
L<Test::Unit::TestCase> and L<Test::Unit::TestSuite>.  (There
will also eventually be a tutorial in
L<Test::Unit::Tutorial>.

However C<Test::Unit::Procedural> is the procedural style
interface to a sophisticated unit testing framework for Perl
that .  Test::Unit is intended to provide a simpler
interface to the framework that is more suitable for use in a
scripting style environment.  Therefore, Test::Unit does not
provide much support for an object-oriented approach to unit
testing.

=head1 COPYRIGHT

Copyright (c) 2000-2002, 2005 the PerlUnit Development Team
(see the F<AUTHORS> file included in this distribution).

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

That is, under the terms of either of:

=over 4

=item *

The GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version.

The text of version 2 is included in the PerlUnit distribution package
as F<COPYING.GPL-2>.

=item *

The "Artistic License" which comes with Perl.

The text of this is included in the PerlUnit distribution package as
F<COPYING.Artistic>.

=back

=head1 SEE ALSO

=over 4

=item *

L<Test::Unit::TestCase>

=item *

L<Test::Unit::TestSuite>

=item *

L<Test::Unit::Procedural>

=back

=head1 FEEDBACK

The Perl Unit development team are humans. In part we develop stuff
because it scratches our collective itch but we'd also really like to
know if it scratches yours.

Please subscribe to the perlunit-users mailing list at
L<http://lists.sourceforge.net/lists/listinfo/perlunit-users> and let
us know what you love and hate about PerlUnit and what else you want
to do with it.

=cut

package Test::Unit;

use strict;
use vars qw($VERSION);

# Note... this version number has to be kept in sync with the
# number in the distribution file name (the distribution file
# is the tarball for CPAN release) because the CPAN module
# decides to fetch the tarball by looking at the version of
# this module if you say "install Test::Unit" in the CPAN
# shell.  "make tardist" should do this automatically.

BEGIN {
    $VERSION = '0.25';
}

# Constants for notices displayed to the user:

use constant COPYRIGHT_SHORT => <<EOF;
Test::Unit Version $Test::Unit::VERSION
(c) 2000-2002, 2005 Christian Lemburg, Brian Ewins, et. al.
EOF


use constant COPYRIGHT_NOTICE => <<'END_COPYRIGHT_NOTICE';
This is PerlUnit version $Test::Unit::VERSION.
Copyright (C) 2000-2002, 2005 Christian Lemburg, Brian Ewins, et. al.


PerlUnit is a Unit Testing framework based on JUnit.
See http://c2.com/cgi/wiki?TestingFrameworks

PerlUnit is free software, redistributable under the
same terms as Perl.
END_COPYRIGHT_NOTICE


1;
__END__
