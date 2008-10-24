package Test::Unit::Warning;

use strict;
use base 'Test::Unit::TestCase';

=head1 NAME

Test::Unit::Warning - helper TestCase for adding warnings to a suite

=head1 DESCRIPTION

Used by L<Test::Unit::TestSuite> and others to provide messages that
come up when the suite runs.

=cut

sub run_test {
    my $self = shift;
    $self->fail($self->{_message});
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new('warning');
    $self->{_message} = shift;
    return $self;
}

1;


=head1 AUTHOR

Copyright (c) 2000-2002, 2005 the PerlUnit Development Team
(see L<Test::Unit> or the F<AUTHORS> file included in this
distribution).

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut

