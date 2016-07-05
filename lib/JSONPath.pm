#!/usr/bin/perl

use strict;
use warnings;
# ABSTRACT:	 A port of the JavaScript and PHP versions of JSONPath L<http://goessner.net/articles/JsonPath/>

# VERSION

#	A port of the JavaScript and PHP versions
#	of JSONPath which is
#	Copyright (c) 2007 Stefan Goessner (goessner.net)
#	Licensed under the MIT licence:
#
#	Permission is hereby granted, free of charge, to any person
#	obtaining a copy of this software and associated documentation
#	files (the "Software"), to deal in the Software without
#	restriction, including without limitation the rights to use,
#	copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the
#	Software is furnished to do so, subject to the following
#	conditions:
#
#	The above copyright notice and this permission notice shall be
#	included in all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#	OTHER DEALINGS IN THE SOFTWARE.

package JSONPath;
use JSON::MaybeXS;
use Log::Any qw($log);
use Scalar::Util qw(looks_like_number);

sub new {
    my $class = shift;
    my $self  = bless {
        obj           => undef,
        result_type   => 'VALUE',
        result        => [],
        subx          => [],
        reserved_locs => {
            '*'  => undef,
            '..' => undef,
        }
    }, $class;
    return $self;

}

=method run

Evaluate a JSONPath expression on the given (parsed) JSON object.

Usage:
    $jp->run( $json_object, $expression, [ \%options ] );

Currently supported options are C<result_type>, which may be PATH or VALUE. PATH returns JSONPath 
expressions for each object matching the expression. VALUE returns the value of each matching 
object.

=cut

sub run {
    my $self = shift;
    $self->{'result'} = ();      #reset it
    $self->{'obj'}    = undef;
    my ( $obj, $expr, $arg ) = @_;

    #my $self->{'obj'} = $obj;
    #$log->debug( "arg: $arg");
    if ( $arg && $arg->{'result_type'} ) {
        my $result_type = $arg->{'result_type'};
        if ( $result_type eq 'PATH' | $result_type eq 'VALUE' ) {
            $self->{'result_type'} = $arg->{'result_type'};
        }
    }
    if ( $expr and $obj and ( $self->{'result_type'} eq 'VALUE' || $self->{'result_type'} eq 'PATH' ) ) {
        my $cleaned_expr = $self->normalize($expr);
        $cleaned_expr =~ s/^\$;//;
         $self->trace( $cleaned_expr, $obj, '$' );
        my @result = @{ $self->{'result'} };

        #print STDERR " ending. result = @result\n";

        if ( $#result > -1 ) {

            #print STDERR " will return result\n";
            return \@result;
        }

        #print STDERR "will return zero\n";
        return 0;
    }
}

=method normalize

normalize the path expression

=cut

sub normalize () {
    my $self = shift;
    my $x    = shift;
    $x =~ s/"\/[\['](\??\(.*?\))[\]']\/"/&_callback_01($1)/eg;
    $x =~ s/'?(?<!@|\d)\.'?|\['?/;/g;    #added the negative lookbehind -krhodes
                                         # added \d in it to compensate when
                                         # comparinig against decimal numbers
    $x =~ s/;;;|;;/;..;/g;
    $x =~ s/;$|'?\]|'$//g;
    $x =~ s/#([0-9]+)/&_callback_02($1)/eg;
    $self->{'result'} = [];
    return $x;
}

sub as_path {
    my $self = shift;
    my $path = shift;

    my @x = split( /;/, $path );
    my $p = '';

    #the JS and PHP versions of this are totally whack
    #foreach my $piece (@x){
    for ( my $i = 1; $i <= $#x; $i++ ) {
        my $piece = $x[$i];
        if ( $piece =~ m/^\d+$/ ) {
            $p .= "[$piece]";
        }
        else {
            $p .= "[\"$piece\"]";
        }
    }
    return $p;
}

sub store {
    my $self   = shift;
    my $path   = shift;
    my $object = shift;
    if ($path) {
        if ( $self->{'result_type'} eq 'PATH' ) {
            push @{ $self->{'result'} }, $self->as_path($path);
        }
        else {
            push @{ $self->{'result'} }, $object;
        }
    }

    #print STDERR "-Updated Result to: \n";
    foreach my $res ( @{ $self->{'result'} } ) {

        #print STDERR "-- $res\n";
    }

    return $path;
}

sub trace {

    #$log->debug( "raw trace args: @_");
    my $self = shift;
    my ( $expr, $obj, $path ) = @_;

    #$log->debug( "in trace. $expr /// $obj /// $path");
    if ($expr) {
        my @x        = split( /;/, $expr );
        my $loc      = shift(@x);
        my $x_string = join( ';', @x );

        #$log->debug("trace... expr: $expr x_string: $x_string");
        my $ref_type     = ref $obj;
        my $reserved_loc = 0;
        if ( exists $self->{'reserved_locs'}->{$loc} ) {
            $reserved_loc = 1;
        }

        #$log->debug("loc: $loc  // $reserved_loc // $ref_type");

        if ( !$reserved_loc and $ref_type eq 'HASH' and ( $obj and exists $obj->{$loc} ) ) {

            #$log->debug( "tracing loc($loc) obj (hash)?");
            $self->trace( $x_string, $obj->{$loc}, $path . ';' . $loc );
        }
        elsif (!$reserved_loc
            and $ref_type eq 'ARRAY'
            and ( $loc =~ m/^\d+$/ and $#{$obj} >= $loc and defined $obj->[$loc] ) )
        {
            $self->trace( $x_string, $obj->[$loc], $path . ';' . $loc );

        }
        elsif ( $loc eq '*' ) {

            #$log->debug( "tracing *");
            $self->walk( $loc, $x_string, $obj, $path, \&_callback_03 );
        }
        elsif ( $loc eq '!' ) {

            #$log->debug( "tracing !");
            $self->walk( $loc, $x_string, $obj, $path, \&_callback_06 );
        }
        elsif ( $loc eq '..' ) {

            #$log->debug( "tracing ..");
            $self->trace( $x_string, $obj, $path );
            $self->walk( $loc, $x_string, $obj, $path, \&_callback_04 );
        }
        elsif ( $loc =~ /,/ ) {

            #$log->debug( "tracing loc w comma");
            foreach my $piece ( split( /'?,'?/, $loc ) ) {
                $self->trace( $piece . ';' . $x_string, $obj, $path );
            }
        }
        elsif ( $loc =~ /^\(.*?\)$/ ) {

            #$log->debug( "tracing loc /^\(.*?\)\$/");
            my $path_end = $path;
            $path_end =~ s/.*;(.).*?$/$1/;

            #WTF is eobjuate?!
            $self->trace( $self->eobjuate( $loc, $obj, $path_end . ';' . $x_string, $obj, $path ) );
        }
        elsif ( $loc =~ /^\?\(.*?\)$/ ) {

            #$log->debug( "tracing loc /^\?\(.*?\)\$/");
            $self->walk( $loc, $x_string, $obj, $path, \&_callback_05 );

            #$log->debug( "after walk w/ 05");
        }
        elsif ( $loc =~ /^(-?[0-9]*):(-?[0-9]*):?([0-9]*)$/ ) {

            #$log->debug( "tracing loc ($loc) for slice");
            $self->slice( $loc, $x_string, $obj, $path );
        }
        elsif ( !$loc and $ref_type eq 'ARRAY' ) {
            $self->store( $path, $obj );
        }
    }
    else {
        #$log->debug( "trace no expr. will store $obj");
        $self->store( $path, $obj );
    }

    #$log->debug( "leaving trace");
}

sub walk () {
    my $self = shift;
    my ( $loc, $expr, $obj, $path, $funct ) = @_;

    #$log->debug( "in walk. $loc /// $expr /// $obj /// $path ");

    if ( ref $obj eq 'ARRAY' ) {

        for ( my $i = 0; $i <= $#{$obj}; $i++ ) {

            #$log->debug( "before Array func call: w/ $i /// $loc /// $expr /// $obj /// $path");
            $funct->( $self, $i, $loc, $expr, $obj, $path );

            #$log->debug( "after func call");

        }
    }
    elsif ( ref $obj eq 'HASH' ) {    # a Hash
        my @keys = keys %{$obj};

        #print STDERR "$#keys keys in hash to iterate over:\n";
        foreach my $key (@keys) {

            #$log->debug( "before Hash func call: w/ $key /// $loc /// $expr /// $obj /// $path");
            $funct->( $self, $key, $loc, $expr, $obj, $path );

            #$log->debug( "after func call");
        }

    }

    #$log->debug( " leaving walk");
}

sub slice {
    my $self = shift;
    my ( $loc, $expr, $obj, $path ) = @_;
    $loc =~ s/^(-?[0-9]*):(-?[0-9]*):?(-?[0-9]*)$/$1:$2:$3/;

    # $3 would be if you wanted to specify the steps between the start and end.

    my @s = split( /:|,/, $loc );

    my $len = 0;
    if ( ref $obj eq 'HASH' ) {
        $len = $#{ keys %{$obj} };
    }
    else {    #array
        $len = $#{$obj};
    }
    my $start = $s[0] ? $s[0] : 0;
    my $end = undef;
    if ( $loc !~ m/^:(\d+):?$/ ) {
        $end = $s[1] ? $s[1] : $len;
    }
    else {
        $end = int( $s[1] ) - 1;
    }

    my $step = $s[2] ? $s[2] : 1;

    #$start = $start < 0 ? ($start + $len > 0 ? $start + $len : 0) : ($len > $start ? $start : $len);
    if ( $start < 0 ) {
        $start = $len > 0 ? $start + $len + 1 : 0;

        #the +1 is so that -1 gets us the last entry, -2 gets us the last two, etc...
    }
    $end = $end < 0 ? ( $end + $len > 0 ? $end + $len : 0 ) : ( $len > $end ? $end : $len );

    #$log->debug("start: $start end: $end step: $step");
    for ( my $x = $start; $x <= $end; $x += $step ) {
        $self->trace( "$x;$expr", $obj, $path );
    }
}

sub evalx {
    my $self = shift;
    my ( $loc, $obj ) = @_;

    #$log->debug( "in evalx: $loc /// $obj");
    #x: @.price<10: [object Object] _vname: 0
    #need to convert @.price<10 to
    #$obj->{'price'} < 10
    #and then evaluate
    #
    #x: @.isbn
    #needs to convert to
    #exists $obj->{'isbn'}

    if ( $loc =~ m/^@\.[a-zA-Z0-9_-]*$/ ) {

        #$log->debug( "existence test ");
        $loc =~ s/@\.([a-zA-Z0-9_-]*)$/exists \$obj->{'$1'}/;
    }
    else {    # it's a comparis on some sort?
        my $obj_type = ref($obj);
        $loc =~ s/@\.([a-zA-Z0-9_-]*)(.*)/\$obj->{'$1'}$2/;
        $loc =~ s/(?<!=)(=)(?!=)/==/;    #convert single equals to double
        if ( $loc =~ m/\s*(!|=)=['"](.*?)['"]/ ) {
            $loc =~ s/\s*==['"](.*?)['"]/ eq "$1"/;
            $loc =~ s/\s*!=['"](.*?)['"]/ ne "$1"/;
            my $string_match = 0;
            if ( $loc =~ m/ (eq|ne) / ) {    #dunno if those replacements happened...
                $string_match = 1;
            }

            #$log->debug( "comparison test of  $1 and $2 ::loc:: $loc");
            if ( $obj_type ne 'HASH' and $obj_type ne 'ARRAY' and $obj ) {
                if ( !$string_match ) {
                    $loc =~ s/\$obj->{(.*?)}(.*)/$obj $2/;
                }
                else {
                    $loc =~ s/\$obj->{(.*?)}(.*)/"$obj" $2/;
                }
                return ( $obj and $loc and eval($loc) ) ? 1 : 0; ## no critic
            }
        }
        elsif ( $loc =~ m/></ ) {
            my $query_item = $loc;
            $query_item =~ s/.*><\s*['"]?([\w\.]*)['"]?\s*/$1/;

            #$log->debug("includes test: $query_item :: $loc ::");
            if ( ( $obj_type eq 'HASH' or $obj_type eq 'ARRAY' ) ) {

                #$log->debug("hash or array");
                if ( $obj_type eq 'HASH' ) {

                    #something like "$..book[?(@.ratings><'good')]"
                    #obj is book
                    my $eval_string = $loc;
                    my $sub_obj     = undef;
                    $eval_string =~ s/(.*?)><.*/$1/;

                    #$eval_string =~ s/(.*?)><.*/\$sub_obj_type = ref $1\->{'$query_item'}/;
                    #$log->debug("eval_string: $eval_string");
                    #set the sub_obj_type
                    eval( '$sub_obj = ' . $eval_string ); ## no critic
                    my $sub_obj_type = ref $sub_obj;

                    #$log->debug("sub_obj_type: $sub_obj_type");
                    if ($sub_obj) {
                        if ( $sub_obj_type eq 'ARRAY' ) {
                            foreach my $item ( @{$sub_obj} ) {
                                if ( looks_like_number($item) && looks_like_number($query_item) ) {
                                    return 1 if $item == $query_item;
                                }
                                else {
                                    return 1 if $item eq $query_item;
                                }
                            }
                            return 0;
                        }
                        elsif ( $sub_obj_type eq 'HASH' ) {
                            return exists( $sub_obj->{$query_item} ) ? 1 : 0;
                        }
                    }
                    else {
                        #$log->debug("no sub_obj");
                    }
                }
            }
            else {
                #$log->debug(" in array item evalling");
                my $returnable = 0;
                if ( !looks_like_number($obj) || !looks_like_number($query_item)  ) {

                    #Does the string include the string they've provided?
                    #return ($obj eq $query_item or $obj =~ m/.*?$query_item.*?/) ? 1 : 0;
                    $returnable = ( $obj eq $query_item or $obj =~ m/.*?$query_item.*?/ ) ? 1 : 0;
                }
                else {
                    #return $obj == $query_item;
                    $returnable = ( $obj == $query_item ) ? 1 : 0;
                }

                #not the best use of the >< operator. we've been drilled down to
                #
                #$log->debug("returning $returnable");
                return $returnable;
            }
        }
        else {
            #$log->debug("loc not equality or includes test: $loc");
        }
    }

    #print STDERR "loc: $loc\n";
    return ( $obj and $loc and eval($loc) ) ? 1 : 0; ## no critic
}

sub _callback_01 {
    my $self = shift;

    #$log->debug( "in 01");
    my $arg = shift;
    push @{ $self->{'result'} }, $arg;
    return '[#' . $#{ $self->{'result'} } . ']';
}

sub _callback_02 {
    my $self = shift;

    #$log->debug( "in 02");
    my $arg = shift;
    return @{ $self->{'result'} }[$arg];
}

sub _callback_03 {
    my $self = shift;

    #$log->debug( " in 03 ");
    my ( $key, $loc, $expr, $obj, $path ) = @_;
    $self->trace( $key . ';' . $expr, $obj, $path );
}

sub _callback_04 {
    my $self = shift;
    my ( $key, $loc, $expr, $obj, $path ) = @_;

    #$log->debug( " in 04. expr = $expr");
    if ( ref $obj eq 'HASH' ) {
        if ( ref( $obj->{$key} ) eq 'HASH' ) {

            #$self->logit( "Passing this to trace: ..;$expr, " . $obj->{$key} . ", $path;$key\n";
            $self->trace( '..;' . $expr, $obj->{$key}, $path . ';' . $key );
        }
        elsif ( ref( $obj->{$key} ) ) {    #array
                #print STDERR "--- \$obj->{$key} wasn't a hash. it was a " . (ref $obj->{$key}) . "\n";
            $self->trace( '..;' . $expr, $obj->{$key}, $path . ';' . $key );
        }
    }
    else {
        #print STDERR "-- obj wasn't a hash. it was a " . (ref $obj) . "\n";
        if ( ref( $obj->[$key] ) eq 'HASH' ) {
            $self->trace( '..;' . $expr, $obj->[$key], $path . ';' . $key );
        }
    }

}

sub _callback_05 {
    my $self = shift;

    #$log->debug( "05");
    my ( $key, $loc, $expr, $obj, $path ) = @_;
    $loc =~ s/^\?\((.*?)\)$/$1/;
    my $eval_result = 0;
    if ( ref $obj eq 'HASH' ) {

        #$log->debug( " in 05 obj: $obj obj->{$key}: ". $obj->{$key});
        $eval_result = $self->evalx( $loc, $obj->{$key} );
    }
    else {
        #$log->debug( " in 05 obj: $obj obj->[$key]: ". $obj->[$key] );
        $eval_result = $self->evalx( $loc, $obj->[$key] );
    }

    #$log->debug( "eval_result: $eval_result");
    if ($eval_result) {

        #$log->debug("IT EVALLED! tracing..");
        $self->trace( "$key;$expr", $obj, $path );
    }

    #$log->debug( "leaving 05");
}

sub _callback_06 {
    my $self = shift;
    my ( $key, $loc, $expr, $obj, $path ) = @_;

    #$log->debug("in 06 $key /// $loc /// $expr /// $obj /// $path" );
    if ( ref $obj eq 'HASH' ) {
        $self->trace( $expr, $key, $path );
    }
}

1;
__END__

=head1 SYNOPSIS

    use JSON::MaybeXS;
    use JSONPath;

    my $json_structure = decode_json(
        q({
           "store" : {
              "bicycle" : {
                 "color" : "red",
                 "price" : 19.95
              },
              "book" : [
                 {
                    "price" : 8.95,
                    "title" : "Sayings of the Century",
                    "author" : "Nigel Rees",
                    "category" : "reference"
                 },
                 {
                    "price" : 12.99,
                    "title" : "Sword of Honour",
                    "author" : "Evelyn Waugh",
                    "category" : "fiction"
                 },
                 {
                    "price" : 8.99,
                    "isbn" : "0-553-21311-3",
                    "title" : "Moby Dick",
                    "author" : "Herman Melville",
                    "category" : "fiction"
                 },
                 {
                    "price" : 22.99,
                    "isbn" : "0-395-19395-8",
                    "title" : "The Lord of the Rings",
                    "author" : "J. R. R. Tolkien",
                    "category" : "fiction"
                 }
              ]
           }
        })
    );

    my $jp = JSONPath->new();
    my $raw_result = $jp->run($json_structure, "$..author"); # either a data structure or zero

    # $raw_result = [ 'Nigel Rees', 'Evelyn Waugh', 'Herman Melville', 'J.R.R. Tolkien' ]

=head1 ABOUT JSONPath

JSONPath is the brainchild of L<Stephan Goessner|http://goessner.net/>. It takes the basic concept 
of XPATH and, using similar syntax, applies it to JSON data structures. This documentation is taken 
directly from L<Stephan's JSONPath page|http://goessner.net/articles/JsonPath/> with minor tweaks 
specific to the Perl port. You can find the JavaScript, PHP, and C# implementation of it on the 
L<JSONPath page at Google Code|http://code.google.com/p/jsonpath/>.

JSONPath is distributed under the MIT License.

=head2 JSONPath expressions

JSONPath expressions always refer to a JSON structure in the same way as XPath expression are used 
in combination with an XML document. Since a JSON structure is usually anonymous and doesn't 
necessarily have a "root member object" JSONPath assumes the abstract name $ assigned to the outer 
level object.

JSONPath expressions can use the dot notation

    $.store.book[0].title

or the bracket notation

    $['store']['book'][0]['title']

for input pathes. Internal or output pathes will always be converted to the more general bracket 
notation.

JSONPath allows the wildcard symbol * for member names and array indices. It borrows the descendant 
operator '..' from E4X and the array slice syntax proposal C<[start:end:step]> from ECMASCRIPT 4.

Expressions of the underlying scripting language () can be used as an alternative to explicit names 
or indices as in

    $.store.book[(@.length-1)].title

using the symbol '@' for the current object. Filter expressions are supported via the syntax ?() as 
in

    $.store.book[?(@.price < 10)].title

XPath has a lot more to offer (Location paths in not abbreviated syntax, operators and functions) 
than listed here. Moreover there is a remarkable difference how the subscript operator works in 
Xpath and JSONPath.

=for :list
* Square brackets in XPath expressions always operate on the node set resulting from the previous path fragment. Indices always start by 1.
* With JSONPath square brackets operate on the object or array addressed by the previous path fragment. Indices always start by 0. 

=head2 JSONPath Examples

Let's practice JSONPath expressions by some more examples. We start with a simple JSON structure 
built after an XML example representing a bookstore.

    { "store": {
        "book": [ 
          { "category": "reference",
            "author": "Nigel Rees",
            "title": "Sayings of the Century",
            "price": 8.95
          },
          { "category": "fiction",
            "author": "Evelyn Waugh",
            "title": "Sword of Honour",
            "price": 12.99
          },
          { "category": "fiction",
            "author": "Herman Melville",
            "title": "Moby Dick",
            "isbn": "0-553-21311-3",
            "price": 8.99
          },
          { "category": "fiction",
            "author": "J. R. R. Tolkien",
            "title": "The Lord of the Rings",
            "isbn": "0-395-19395-8",
            "price": 22.99
          }
        ],
        "bicycle": {
          "color": "red",
          "price": 19.95
        }
      }
    }

Here are examples of all the types of JSONPath expressions you could perform on this and what you 
should expect to see as a result. We've also included the comparable XPath expressions.

    XPath               JSONPath                Result
    /store/book/author   $.store.book[*].author  the authors of all books in the store
    //author             $..author               all authors
    /store/*             $.store.*               all things in store, which are some books and a red bicycle.
    /store//price        $.store..price          the price of everything in the store.
    //book[3]            $..book[2]              the third book
    //book[last()]       $..book[(@.length-1)]
    //book[position()<3] $..book[-1:]            the last book in order.
                         $..book[0,1]
                         $..book[:2]             the first two books
    //book[isbn]         $..book[?(@.isbn)]      filter all books with isbn number
    //book[price<10]     $..book[?(@.price<10)]  filter all books cheapier than 10
    //*                  $..*                    all Elements in XML document. All members of JSON structure.
    ???                  $.store.!               all the keys in the store hash (bicycle, book)
                         $..book[?(@.ratings><'good')]
                                                all the books with a ratings element that contains the word "good"
                                                This could be a key in a hash, an item in an array,
                                                or a substring of a string.

=head2 JSONPath Implementation

JSONPath.pm is a simple perl class, ported from the Javascript and PHP versions, that can be wrapped
within a script like jsonpath.pl to give command line inspection into a JSON file or leveraged in a 
larger application. To use it simply parse the JSON with your favorite JSON library, create an 
instance of JSONPath, and pass the parsed json to its run method along with your JSONPath expression

    use JSON;
    my $json_structure = from_json($raw_json);
    my $jp = JSONPath->new();
    my $raw_result = $jp->run($json_structure, "$..author"); # either a data structure or zero
    print to_json($raw_result, {utf8 => 1, pretty => 1}) . "\n";

The run method also takes an optional third argument, a hash with any options. Currently the only 
supported option is "result_type" which can be "VALUE" or "PATH".

the example results in the following arrays:

    res1:
    [ "Nigel Rees",
      "Evelyn Waugh",
      "Herman Melville",
      "J. R. R. Tolkien"
    
    ]

    res2:   
    [ "$['store']['book'][0]['author']",
      "$['store']['book'][1]['author']",
      "$['store']['book'][2]['author']",
      "$['store']['book'][3]['author']"
    ]

Please note, that the return value of jsonPath is an array, which is also a valid JSON structure. 
So you might want to apply jsonPath to the resulting structure again or use one of your favorite 
array methods as sort with it.

=head1 ISSUES

=for :list
* Currently only single quotes allowed inside of JSONPath expressions.
* Script expressions inside of JSONPath locations are currently not recursively evaluated by jsonPath. Only the global $ and local @ symbols are expanded by a simple regular expression.
* An alternative for jsonPath to return false in case of no match may be to return an empty array in future.
