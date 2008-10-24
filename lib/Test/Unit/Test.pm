package Test::Unit::Test;
use strict;

use Carp;

use Test::Unit::Debug qw(debug);

use base qw(Test::Unit::Assert);

sub count_test_cases {
    my $self = shift;
    my $class = ref($self);
    croak "call to abstract method ${class}::count_test_cases";
}

sub run {
    my $self = shift;
    my $class = ref($self);
    croak "call to abstract method ${class}::run";
}

sub name {
    my $self = shift;
    my $class = ref($self);
    croak "call to abstract method ${class}::name";
}

sub to_string {
    my $self = shift;
    return $self->name();
}

sub filter_method {
    my $self = shift;
    my ($token) = @_;

    my $filtered = $self->filter->{$token};
    return unless $filtered;

    if (ref $filtered eq 'ARRAY') {
        return grep $self->name eq $_, @$filtered;
    }
    elsif (ref $filtered eq 'CODE') {
        return $filtered->($self->name);
    }
    else {
        die "Didn't understand filtering definition for token $token in ",
            ref($self), "\n";
    }
}

my %filter = ();

sub filter { \%filter }

# use Attribute::Handlers;
    
# sub Filter : ATTR(CODE) {
#     my ($pkg, $symbol, $referent, $attr, $data, $phase) = @_;
#     print "attr $attr (data $data) on $pkg\::*{$symbol}{NAME}\n";
# #    return ();
# }

sub _find_sym { # pinched from Attribute::Handlers
    my ($pkg, $ref) = @_;
    my $type = ref($ref);
    no strict 'refs';
    warn "type $type\n";
    while (my ($name, $sym) = each %{$pkg."::"} ) {
        use Data::Dumper;
#        warn Dumper(*$sym);
        warn "name $name sym $sym (" . (*{$sym}{$type} || '?') . ") matches?\n";
        return \$sym if *{$sym}{$type} && *{$sym}{$type} == $ref;
    }
}

sub MODIFY_CODE_ATTRIBUTES {
    my ($pkg, $subref, @attrs) = @_;
    my @bad = ();
    foreach my $attr (@attrs) {
        if ($attr =~ /^Filter\((.*)\)$/) {
            my @tokens = split /\s+|\s*,\s*/, $1;
            my $sym = _find_sym($pkg, $subref);
            if ($sym) {
                push @{ $filter{$_} }, *{$sym}{NAME} foreach @tokens;
            }
            else {
                warn "Couldn't find symbol for $subref in $pkg\n" unless $sym;
                push @bad, $attr;
            }
        }
        else {
            push @bad, $attr;
        }
    }
    return @bad;
}

1;
__END__


=head1 NAME

Test::Unit::Test - unit testing framework abstract base class

=head1 SYNOPSIS

This class is not intended to be used directly 

=head1 DESCRIPTION

This class is used by the framework to define the interface of a test.
It is an abstract base class implemented by Test::Unit::TestCase and
Test::Unit::TestSuite.

Due to the nature of the Perl OO implementation, this class is not
really needed, but rather serves as documentation of the interface.

=head1 AUTHOR

Copyright (c) 2000-2002, 2005 the PerlUnit Development Team
(see L<Test::Unit> or the F<AUTHORS> file included in this
distribution).

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item *

L<Test::Unit::Assert>

=item *

L<Test::Unit::TestCase>

=item *

L<Test::Unit::TestSuite>

=back

=cut
