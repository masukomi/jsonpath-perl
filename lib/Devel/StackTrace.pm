package Devel::StackTrace;

use 5.005;

use strict;
use vars qw($VERSION);

use File::Spec;

use overload
    '""' => \&as_string,
    fallback => 1;

$VERSION = '1.15';


sub new
{
    my $class = shift;
    my %p = @_;

    # Backwards compatibility - this parameter was renamed to no_refs
    # ages ago.
    $p{no_refs} = delete $p{no_object_refs}
        if exists $p{no_object_refs};

    my $self =
        bless { index  => undef,
                frames => [],
                raw    => [],
                %p,
              }, $class;

    $self->_record_caller_data();

    return $self;
}

sub _record_caller_data
{
    my $self = shift;

    # We exclude this method by starting one frame back.
    my $x = 1;
    while ( my @c =
            do { package DB; @DB::args = (); caller($x++) } )
    {
        my @a = @DB::args;
        push @{ $self->{raw} },
            { caller => \@c,
              args   => \@a,
            };
    }
}

sub _make_frames
{
    my $self = shift;

    my (@i_pack_re, %i_class);
    if ( $self->{ignore_package} )
    {
        $self->{ignore_package} =
            [ $self->{ignore_package} ] unless UNIVERSAL::isa( $self->{ignore_package}, 'ARRAY' );

        @i_pack_re = map { ref $_ ? $_ : qr/^\Q$_\E$/ } @{ $self->{ignore_package} };
    }

    if ( $self->{ignore_class} )
    {
        $self->{ignore_class} = [ $self->{ignore_class} ] unless ref $self->{ignore_class};
        %i_class = map {$_ => 1} @{ $self->{ignore_class} };
    }

    my $p = __PACKAGE__;
    push @i_pack_re, qr/^\Q$p\E$/;

    my $raw = delete $self->{raw};
    for my $r ( @{$raw} )
    {
        next if grep { $r->{caller}[0] =~ /$_/ } @i_pack_re;
        next if grep { $r->{caller}[0]->isa($_) } keys %i_class;

        $self->_add_frame( $r->{caller}, $r->{args} );
    }
}

sub _add_frame
{
    my $self = shift;
    my $c    = shift;
    my $args = shift;

    # eval and is_require are only returned when applicable under 5.00503.
    push @$c, (undef, undef) if scalar @$c == 6;

    if ( $self->{no_refs} )
    {
        for ( grep { ref } @{$args} )
        {
            # I can't remember what this is about but I think
            # it must be to avoid a loop between between
            # Exception::Class and this module.
            if ( UNIVERSAL::isa( $_, 'Exception::Class::Base' ) )
            {
                $_ = do { if ( $_->can('show_trace') )
                          {
                              my $t = $_->show_trace;
                              $_->show_trace(0);
                              my $s = "$_";
                              $_->show_trace($t);
                              $s;
                          }
                          else
                          {
                              # hack but should work with older
                              # versions of E::C::B
                              $_->{message};
                          }
                        };
            }
            else
            {
                $_  = $self->_ref_as_string($_);
            }
        }
    }

    push @{ $self->{frames} },
        Devel::StackTraceFrame->new( $c, $args, $self->{respect_overload} );
}

sub _ref_as_string
{
    my $self = shift;

    return overload::StrVal($_[0]) unless $self->{respect_overload};
    # force stringification
    return $_[0] . '';
}

sub next_frame
{
    my $self = shift;

    # reset to top if necessary.
    $self->{index} = -1 unless defined $self->{index};

    my @f = $self->frames();
    if ( defined $f[ $self->{index} + 1 ] )
    {
        return $f[ ++$self->{index} ];
    }
    else
    {
        $self->{index} = undef;
        return undef;
    }
}

sub prev_frame
{
    my $self = shift;

    my @f = $self->frames();

    # reset to top if necessary.
    $self->{index} = scalar @f unless defined $self->{index};

    if ( defined $f[ $self->{index} - 1 ] && $self->{index} >= 1 )
    {
        return $f[ --$self->{index} ];
    }
    else
    {
        $self->{index} = undef;
        return undef;
    }
}

sub reset_pointer
{
    my $self = shift;

    $self->{index} = undef;
}

sub frames
{
    my $self = shift;

    $self->_make_frames() if $self->{raw};

    return @{ $self->{frames} };
}

sub frame
{
    my $self = shift;
    my $i = shift;

    return unless defined $i;

    return ( $self->frames() )[$i];
}

sub frame_count
{
    my $self = shift;

    return scalar ( $self->frames() );
}

sub as_string
{
    my $self = shift;

    my $st = '';
    my $first = 1;
    foreach my $f ( $self->frames() )
    {
        $st .= $f->as_string($first) . "\n";
        $first = 0;
    }

    return $st;
}

package Devel::StackTraceFrame;

use strict;
use vars qw($VERSION);

$VERSION = '0.6';

# Create accessor routines
BEGIN
{
    no strict 'refs';
    foreach my $f ( qw( package filename line subroutine hasargs
                        wantarray evaltext is_require hints bitmask args ) )
    {
        next if $f eq 'args';
        *{$f} = sub { my $s = shift; return $s->{$f} };
    }
}

{
    my @fields =
        ( qw( package filename line subroutine hasargs wantarray evaltext is_require ) );
    push @fields, ( qw( hints bitmask ) ) if $] >= 5.006;

    sub new
    {
        my $proto = shift;
        my $class = ref $proto || $proto;

        my $self = bless {}, $class;

        @{ $self }{ @fields } = @{$_[0]};

        # fixup unix-style paths on win32
        $self->{filename} = File::Spec->canonpath( $self->{filename} );

        $self->{args} = $_[1];

        $self->{respect_overload} = $_[2];

        return $self;
    }
}

sub args
{
    my $self = shift;

    return @{ $self->{args} };
}

sub as_string
{
    my $self = shift;
    my $first = shift;

    my $sub = $self->subroutine;
    # This code stolen straight from Carp.pm and then tweaked.  All
    # errors are probably my fault  -dave
    if ($first)
    {
        $sub = 'Trace begun';
    }
    else
    {
        # Build a string, $sub, which names the sub-routine called.
        # This may also be "require ...", "eval '...' or "eval {...}"
        if (my $eval = $self->evaltext)
        {
            if ($self->is_require)
            {
                $sub = "require $eval";
            }
            else
            {
                $eval =~ s/([\\\'])/\\$1/g;
                $sub = "eval '$eval'";
            }
        }
        elsif ($sub eq '(eval)')
        {
            $sub = 'eval {...}';
        }

        # if there are any arguments in the sub-routine call, format
        # them according to the format variables defined earlier in
        # this file and join them onto the $sub sub-routine string
        #
        # We copy them because they're going to be modified.
        #
        if ( my @a = $self->args )
        {
            for (@a)
            {
                # set args to the string "undef" if undefined
                $_ = "undef", next unless defined $_;

                # hack!
                $_ = $self->Devel::StackTrace::_ref_as_string($_)
                    if ref $_;

                s/'/\\'/g;

                # 'quote' arg unless it looks like a number
                $_ = "'$_'" unless /^-?[\d.]+$/;

                # print control/high ASCII chars as 'M-<char>' or '^<char>'
                s/([\200-\377])/sprintf("M-%c",ord($1)&0177)/eg;
                s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;
            }

            # append ('all', 'the', 'arguments') to the $sub string
            $sub .= '(' . join(', ', @a) . ')';
            $sub .= ' called';
        }
    }

    return "$sub at " . $self->filename . ' line ' . $self->line;
}

1;


__END__

=head1 NAME

Devel::StackTrace - Stack trace and stack trace frame objects

=head1 SYNOPSIS

  use Devel::StackTrace;

  my $trace = Devel::StackTrace->new;

  print $trace->as_string; # like carp

  # from top (most recent) of stack to bottom.
  while (my $frame = $trace->next_frame)
  {
      print "Has args\n" if $frame->hasargs;
  }

  # from bottom (least recent) of stack to top.
  while (my $frame = $trace->prev_frame)
  {
      print "Sub: ", $frame->subroutine, "\n";
  }

=head1 DESCRIPTION

The Devel::StackTrace module contains two classes, Devel::StackTrace
and Devel::StackTraceFrame.  The goal of this object is to encapsulate
the information that can found through using the caller() function, as
well as providing a simple interface to this data.

The Devel::StackTrace object contains a set of Devel::StackTraceFrame
objects, one for each level of the stack.  The frames contain all the
data available from caller() as of Perl 5.6.0 though this module still
works with 5.00503.

This code was created to support my L<Exception::Class::Base> class
(part of Exception::Class) but may be useful in other contexts.

=head1 'TOP' AND 'BOTTOM' OF THE STACK

When describing the methods of the trace object, I use the words 'top'
and 'bottom'.  In this context, the 'top' frame on the stack is the
most recent frame and the 'bottom' is the least recent.

Here's an example:

  foo();  # bottom frame is here

  sub foo
  {
     bar();
  }

  sub bar
  {
     Devel::StackTrace->new;  # top frame is here.
  }

=head1 Devel::StackTrace METHODS

=over 4

=item * Devel::StackTrace->new(%named_params)

Returns a new Devel::StackTrace object.

Takes the following parameters:

=over 8

=item * ignore_package => $package_name OR \@package_names

Any frames where the package is one of these packages will not be on
the stack.

=item * ignore_class => $package_name OR \@package_names

Any frames where the package is a subclass of one of these packages
(or is the same package) will not be on the stack.

Devel::StackTrace internally adds itself to the 'ignore_package'
parameter, meaning that the Devel::StackTrace package is B<ALWAYS>
ignored.  However, if you create a subclass of Devel::StackTrace it
will not be ignored.

=item * no_refs => $boolean

If this parameter is true, then Devel::StackTrace will not store
references internally when generating stacktrace frames.  This lets
your objects go out of scope.

Devel::StackTrace replaces any references with their stringified
representation.

=item * respect_overload => $boolean

By default, Devel::StackTrace will call C<overload::StrVal()> to get
the underlying string representation of an object, instead of
respecting the object's stringification overloading.  If you would
prefer to see the overloaded representation of objects in stack
traces, then set this parameter to true.

=back

=item * $trace->next_frame

Returns the next Devel::StackTraceFrame object down on the stack.  If
it hasn't been called before it returns the first frame.  It returns
undef when it reaches the bottom of the stack and then resets its
pointer so the next call to C<next_frame> or C<prev_frame> will work
properly.

=item * $trace->prev_frame

Returns the next Devel::StackTraceFrame object up on the stack.  If it
hasn't been called before it returns the last frame.  It returns undef
when it reaches the top of the stack and then resets its pointer so
pointer so the next call to C<next_frame> or C<prev_frame> will work
properly.

=item * $trace->reset_pointer

Resets the pointer so that the next call C<next_frame> or
C<prev_frame> will start at the top or bottom of the stack, as
appropriate.

=item * $trace->frames

Returns a list of Devel::StackTraceFrame objects.  The order they are
returned is from top (most recent) to bottom.

=item * $trace->frame ($index)

Given an index, returns the relevant frame or undef if there is not
frame at that index.  The index is exactly like a Perl array.  The
first frame is 0 and negative indexes are allowed.

=item * $trace->frame_count

Returns the number of frames in the trace object.

=item * $trace->as_string

Calls as_string on each frame from top to bottom, producing output
quite similar to the Carp module's cluck/confess methods.

=back

=head1 Devel::StackTraceFrame METHODS

See the L<caller> documentation for more information on what these
methods return.

=over 4

=item * $frame->package

=item * $frame->filename

=item * $frame->line

=item * $frame->subroutine

=item * $frame->hasargs

=item * $frame->wantarray

=item * $frame->evaltext

Returns undef if the frame was not part of an eval.

=item * $frame->is_require

Returns undef if the frame was not part of a require.

=item * $frame->args

Returns the arguments passed to the frame.  Note that any arguments
that are references are returned as references, not copies.

=back

=head2 These only contain data as of Perl 5.6.0 or later

=over 4

=item * $frame->hints

=item * $frame->bitmask

=back

=head1 SUPPORT

Please submit bugs to the CPAN RT system at
http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel%3A%3AStackTrace
or via email at bug-devel-stacktrace@rt.cpan.org.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 COPYRIGHT

Copyright (c) 2000-2006 David Rolsky.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=cut
