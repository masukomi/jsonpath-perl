package JSONPathTest;

use strict;
use FindBin qw($Bin);
use JSON::MaybeXS;
use JSONPath;
use Path::Tiny;
use Test::Most;

my %test_structure = %{ decode_json( path(qq{$Bin/fixtures/test.json})->slurp_raw ) };

subtest normalize => sub {
    my $jp         = JSONPath->new();
    my $normalized = $jp->normalize('$..author');
    is( $normalized, '$;..;author' );
    $normalized = $jp->normalize('$.store.book[*].author');
    is( $normalized, '$;store;book;*;author' );
    $normalized = $jp->normalize('$.store.book[*]');
    is( $normalized, '$;store;book;*' );
    $normalized = $jp->normalize('$.store.*');
    is( $normalized, '$;store;*' );
    $normalized = $jp->normalize('$..book[2]');
    is( $normalized, '$;..;book;2' );
    $normalized = $jp->normalize('$..book[(@.length-1)]');
    is( $normalized, '$;..;book;(@.length-1)' );
    $normalized = $jp->normalize('$..book[-1:]');
    is( $normalized, '$;..;book;-1:' );
    $normalized = $jp->normalize('$..book[0,1]');
    is( $normalized, '$;..;book;0,1' );
    $normalized = $jp->normalize('$..book[:2]');
    is( $normalized, '$;..;book;:2' );
    $normalized = $jp->normalize('$..book[?(@.isbn)]');
    is( $normalized, '$;..;book;?(@.isbn)' );
    $normalized = $jp->normalize('$..book[?(@.price<10)]');
    is( $normalized, '$;..;book;?(@.price<10)' );
    $normalized = $jp->normalize('$.store..price');
    is( $normalized, '$;store;..;price' );
    $normalized = $jp->normalize('$..*');
    is( $normalized, '$;..;*' );
};

subtest array_retrieval => sub {
    my $jp         = JSONPath->new();
    my $raw_result = undef;
    my @result     = undef;

    $raw_result = $jp->run( \%test_structure, '$.store.book[*].author' );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 3 );

    $raw_result = $jp->run( \%test_structure, '$.store.book[*]' );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 3 );

    $raw_result = $jp->run( \%test_structure, '$.store.book.*' );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 3 );

    $raw_result = $jp->run( \%test_structure, '$..author' );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 3 );

    $raw_result = $jp->run( \%test_structure, '$..book[?(@.price<10)]' );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};

    #[
    #	{"category":"reference", "author":"Nigel Rees", "title":"Sayings of the Century", "price":8.95},
    #	{"category":"fiction", "author":"Herman Melville", "title":"Moby Dick", "isbn":"0-553-21311-3", "price":8.99}
    #]
    is( $#result, 1 );
    foreach my $book_map (@result) {    # order isn't guaranteed
        ok( defined $book_map->{'category'} );
        ok( defined $book_map->{'author'} );
        ok( defined $book_map->{'title'} );
        ok( defined $book_map->{'price'} );
        if ( defined $book_map->{'isbn'} ) {

            # moby dick
            is( $book_map->{'price'}, 8.99 );
            is( $book_map->{'title'}, 'Moby Dick' );
        }
        else {
            #sayings of the century
            is( $book_map->{'price'}, 8.95 );
            is( $book_map->{'title'}, 'Sayings of the Century' );
        }
    }

    $raw_result = $jp->run( \%test_structure, '$.store.*' );    #book array and one bicycle
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 1 );

    $raw_result = $jp->run( \%test_structure, '$.store..price' );    #the price of everything
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 4 );
    my %prices = (
        19.95 => undef,
        8.95  => undef,
        12.99 => undef,
        8.99  => undef,
        22.99 => undef
    );

    foreach my $price (@result) {
        ok( exists $prices{$price} );
    }

    $raw_result = $jp->run( \%test_structure, '$..book[0,1]' );    # the first two books
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 1 );

    $raw_result = $jp->run( \%test_structure, '$..book[:2]' );     # the first two books
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 1 );

    $raw_result = $jp->run( \%test_structure, '$..book[-1:]' );    # the last book
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 0 );

    $raw_result = $jp->run( \%test_structure, '$..book[?(@.isbn)]' );    #the price of everything
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 1 );

    $raw_result = $jp->run( \%test_structure, '$.store.!' );             #the keys in the store hash
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 1 );

    #The $..* path appears to work just fine, I'm just unsure as to how best to test it...
    #
    #	$raw_result = $jp->run(\%test_structure, '$..*'); #the price of everything
    #	isnt($raw_result, 0);
    #	@result = @{$raw_result};
    #	is($#result, 1);

};

subtest path_operations => sub {
    my $jp         = JSONPath->new();
    my $raw_result = undef;
    my @result     = undef;

    $raw_result = $jp->run( \%test_structure, '$..author', { 'result_type' => 'PATH' } );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 3 );

    is( $result[0], "[\"store\"][\"book\"][0][\"author\"]" );
    is( $result[1], "[\"store\"][\"book\"][1][\"author\"]" );
    is( $result[2], "[\"store\"][\"book\"][2][\"author\"]" );
    is( $result[3], "[\"store\"][\"book\"][3][\"author\"]" );

    $raw_result = $jp->run( \%test_structure, '$.store.!', { 'result_type' => 'PATH' } );
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 1 );

    is( $result[0], "[\"store\"]" );
    is( $result[1], "[\"store\"]" );
};

subtest includes_test => sub {
    my $jp         = JSONPath->new();
    my $raw_result = undef;
    my @result     = undef;

    $raw_result = $jp->run( \%test_structure, "\$..book[?(@.ratings><'good')]" );

    #[
    #   {
    #      "ratings" : [
    #         "good",
    #         "bad",
    #         "lovely"
    #      ],
    #      "category" : "fiction",
    #      "author" : "Evelyn Waugh",
    #      "title" : "Sword of Honour",
    #      "price" : 12.99
    #   }
    #]
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result, 0 );
    $raw_result = $jp->run( \%test_structure, "\$..ratings[?(@.><'good')]" );

    #[
    #   [
    #      "good",
    #      "bad",
    #      "lovely"
    #   ]
    #]
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result,      0 );
    is( $result[0][1], 'bad' );

    $raw_result = $jp->run( \%test_structure, "\$..book[?(@.ratings><3)]" );

    #[
    #   {
    #      "ratings" : [
    #         1,
    #         3,
    #         2,
    #         10
    #      ],
    #      "category" : "reference",
    #      "author" : "Nigel Rees",
    #      "title" : "Sayings of the Century",
    #      "price" : 8.95
    #   }
    #]
    isnt( $raw_result, 0 );
    @result = @{$raw_result};
    is( $#result,                  0 );
    is( $result[0]{'category'},    'reference' );
    is( ref $result[0]{'ratings'}, 'ARRAY' );
    is( $result[0]{'ratings'}[2],  2 );
    #
    #
};

done_testing;
