package Test::Unit::Runner;

=head1 NAME

Test::Unit::Runner - abstract base class for test runners

=head1 SYNOPSIS

    my $runner = Test::Unit::TestRunner->new();
    $runner->filter(@filter_tokens);
    $runner->start(...);

=head1 DESCRIPTION

This class is a parent class of all test runners, and hence is not
intended to be used directly.  It provides functionality such as state
(e.g. run-time options) available to all runner classes.

=cut

use strict;

use Test::Unit::Result;

use base qw(Test::Unit::Listener);

sub create_test_result {
  my $self = shift;
  return $self->{_result} = Test::Unit::Result->new();
}

sub result { shift->{_result} }

sub start_suite {
    my $self = shift;
    my ($suite) = @_;
    push @{ $self->{_suites_running} }, $suite;
} 

sub end_suite {
    my $self = shift;
    my ($suite) = @_;
    pop @{ $self->{_suites_running} };
}

=head2 suites_running()

Returns an array stack of the current suites running.  When a new
suite is started, it is pushed on the stack, and it is popped on
completion.  Hence the first element in the returned array is
the top-level suite, and the last is the innermost suite.

=cut

sub suites_running {
    my $self = shift;
    return @{ $self->{_suites_running} || [] };
}

=head2 filter([ @tokens ])

Set the runner's filter tokens to the given list.

=cut

sub filter {
    my $self = shift;
    $self->{_filter} = [ @_ ] if @_;
    return @{ $self->{_filter} || [] };
}

=head2 reset_filter()

Clears the current filter.

=cut

sub reset_filter {
    my $self = shift;
    $self->{_filter} = [];    
}

1;

=head1 AUTHOR

Copyright (c) 2000-2002, 2005 the PerlUnit Development Team
(see L<Test::Unit> or the F<AUTHORS> file included in this
distribution).

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Unit::HarnessUnit>,
L<Test::Unit::TestRunner>,
L<Test::Unit::TkTestRunner>

=cut
