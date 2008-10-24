package Class::Inner;

use vars qw/$VERSION/;

$VERSION = 0.1;


use strict;
use Carp;

=head1 NAME

Class::Inner - A perlish implementation of Java like inner classes

=head1 SYNOPSIS

    use Class::Inner;

    my $object = Class::Inner->new(
	parent => 'ParentClass',
        methods => { method => sub { ... } }, },
        constructor => 'new',
        args => [@constructor_args],
    );

=head1 DESCRIPTION

Yet another implementation of an anonymous class with per object
overrideable methods, but with the added attraction of sort of working
dispatch to the parent class's method.

=head2 METHODS

=over 4

=item B<new HASH>

Takes a hash like argument list with the following keys.

=over 4

=item B<parent>

The name of the parent class. Note that you can only get single
inheritance with this or B<SUPER> won't work.

=item B<methods>

A hash, keys are method names, values are CODEREFs.

=item B<constructor>

The name of the constructor method. Defaults to 'new'.

=item B<args>

An anonymous array of arguments to pass to the constructor. Defaults
to an empty list.

=back

Returns an object in an 'anonymous' class which inherits from the
parent class. This anonymous class has a couple of 'extra' methods:

=over 4

=item B<SUPER>

If you were to pass something like

    $obj = Class::Inner->new(
	parent  => 'Parent',
	methods => { method =>  sub { ...; $self->SUPER::method(@_) } },
    );

then C<$self-C<gt>SUPER::method> almost certainly wouldn't do what you expect,
so we provide the C<SUPER> method which dispatches to the parent 
implementation of the current method. There seems to be no good way of
getting the full C<SUPER::> functionality, but I'm working on it.

=item B<DESTROY>

Because B<Class::Inner> works by creating a whole new class name for your
object, it could potentially leak memory if you create a lot of them. So we
add a C<DESTROY> method that removes the class from the symbol table once
it's finished with.

If you need to override a parent's DESTROY method, adding a call to
C<Class::Inner::clean_symbol_table(ref $self)> to it. Do it at the
end of the method or your other method calls won't work.

=back

=cut

#'

sub new {
    my $class	    = shift;
    my %args	    = ref($_[0]) ? %{$_[0]} : @_;
    my $parent	    = $args{parent} or
	croak "Can't work without a parent class\n";
    my %methods	    = %{$args{methods}||{}};
    my $constructor = $args{constructor} || 'new';
    my @constructor_args = @{$args{args} || []};

    my $anon_class = $class->new_classname;

    no strict 'refs';

    @{"$anon_class\::ISA"} = $parent;

    foreach my $methodname (keys %methods) {
	*{"$anon_class\::$methodname"} = sub {
	    local $Class::Inner::target_method = $methodname;
	    $methods{$methodname}->(@_);
	};
    }

    # Add the SUPER method.

    unless (exists $methods{SUPER}) {
	*{"$anon_class\::SUPER"} = sub {
	    my $self = shift;
	    my $target_method =
		join '::', $parent, $Class::Inner::target_method;
	    $self->$target_method(@_);
	};
    }

    unless (exists $methods{DESTROY}) {
	*{"$anon_class\::DESTROY"} = sub {
	    my $self = shift;
	    Class::Inner::clean_symbol_table($anon_class);
	    bless $self, $parent;
	}
    }
    # Instantiate
    my $obj = $anon_class->new(@constructor_args);
}

=item B<clean_symbol_table>

The helper subroutine that DESTROY uses to remove the class from the
symbol table.

=cut

sub clean_symbol_table {
    my $class = shift;
    no strict 'refs';
    foreach my $symbol (keys %{"$class\::"}) {
	delete ${"$class\::"}{$symbol};
    }
    delete $::{"$class\::"};	
}

=item B<new_classname>

Returns a name for the next anonymous class.

=cut

{
    my $class_counter;

    sub new_classname {
	my $baseclass = ref($_[0]) || $_[0];
	return "$baseclass\::__A" . $class_counter++;
    }
}

1;
__END__

=back

=head1 AUTHOR

Copyright (c) 2001 by Piers Cawley E<lt>pdcawley@iterative-software.comE<gt>.

All rights reserved. This program is free software; you can redistribute it
and/or modify it under the same terms as perl itself.

Thanks to the Iterative Software people: Leon Brocard, Natalie Ford and 
Dave Cross. Also, this module was written initially for use in the
PerlUnit project, AKA Test::Unit. Kudos to Christian Lemburg and the rest
of that team.

=head1 SEE ALSO

There are a million and one differen Class constructors available on CPAN,
none of them does quite what I want, so I wrote this one to add to
that population where hopefully it will live and thrive.

=head1 BUGS

Bound to be some. Actually the C<SUPER> method is a workaround for what
I consider to be a bug in perl.
