package JSONPathTest;

use strict;
use JSON;
use JSONPath;
use base qw(Test::Unit::TestCase);

my %test_structure =(
	"store"=> {
		"book"=> [ 
			{
				"category"=> "reference",
				"author"=> "Nigel Rees",
				"title"=> "Sayings of the Century",
				"price"=> 8.95,
				"ratings"=> [
					1,
					3,
					2,
					10
				]
			},
			{ 
				"category"=> "fiction",
				"author"=> "Evelyn Waugh",
				"title"=> "Sword of Honour",
				"price"=> 12.99,
				"ratings" => [
						"good",
						"bad",
						"lovely"
					]
			},
			{
				"category"=> "fiction",
				"author"=> "Herman Melville",
				"title"=> "Moby Dick",
				"isbn"=> "0-553-21311-3",
				"price"=> 8.99
			},
			{
				"category"=> "fiction",
				"author"=> "J. R. R. Tolkien",
				"title"=> "The Lord of the Rings",
				"isbn"=> "0-395-19395-8",
				"price"=> 22.99
			}
		],
		"bicycle"=> {
			"color"=> "red",
			"price"=> 19.95
		}
	}
);


sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}


sub test_normalize(){
	my $self = shift;
	my $jp = JSONPath->new();
	my $normalized = $jp->normalize('$..author');
	$self->assert_equals('$;..;author', $normalized);
	$normalized = $jp->normalize('$.store.book[*].author');
	$self->assert_equals('$;store;book;*;author', $normalized);
	$normalized = $jp->normalize('$.store.book[*]');
	$self->assert_equals('$;store;book;*', $normalized);
	$normalized = $jp->normalize('$.store.*');
	$self->assert_equals('$;store;*', $normalized);
	$normalized = $jp->normalize('$..book[2]');
	$self->assert_equals('$;..;book;2', $normalized);
	$normalized = $jp->normalize('$..book[(@.length-1)]');
	$self->assert_equals('$;..;book;(@.length-1)', $normalized);
	$normalized = $jp->normalize('$..book[-1:]');
	$self->assert_equals('$;..;book;-1:', $normalized);
	$normalized = $jp->normalize('$..book[0,1]');
	$self->assert_equals('$;..;book;0,1', $normalized);
	$normalized = $jp->normalize('$..book[:2]');
	$self->assert_equals('$;..;book;:2', $normalized);
	$normalized = $jp->normalize('$..book[?(@.isbn)]');
	$self->assert_equals('$;..;book;?(@.isbn)', $normalized);
	$normalized = $jp->normalize('$..book[?(@.price<10)]');
	$self->assert_equals('$;..;book;?(@.price<10)', $normalized);
	$normalized = $jp->normalize('$.store..price');
	$self->assert_equals('$;store;..;price', $normalized);
	$normalized = $jp->normalize('$..*');
	$self->assert_equals('$;..;*', $normalized);
}

sub test_array_retreival(){
	my $self = shift;
	my $jp = JSONPath->new();
	my $raw_result = undef;
	my @result = undef;

	$raw_result = $jp->run(\%test_structure, '$.store.book[*].author');
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(3, $#result);

	$raw_result = $jp->run(\%test_structure, '$.store.book[*]');
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(3, $#result);

	$raw_result = $jp->run(\%test_structure, '$.store.book.*');
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(3, $#result);


	$raw_result = $jp->run(\%test_structure, '$..author');
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(3, $#result);



	$raw_result = $jp->run(\%test_structure, '$..book[?(@.price<10)]');
	$self->assert($raw_result != 0);
	my @result = @{$raw_result};
	#[
	#	{"category":"reference", "author":"Nigel Rees", "title":"Sayings of the Century", "price":8.95}, 
	#	{"category":"fiction", "author":"Herman Melville", "title":"Moby Dick", "isbn":"0-553-21311-3", "price":8.99}
	#]
	$self->assert_equals(1, $#result);
	foreach my $book_map (@result){ # order isn't guaranteed
		$self->assert(defined $book_map->{'category'});
		$self->assert(defined $book_map->{'author'});
		$self->assert(defined $book_map->{'title'});
		$self->assert(defined $book_map->{'price'});
		if (defined $book_map->{'isbn'}){
			# moby dick
			$self->assert_equals(8.99, $book_map->{'price'});
			$self->assert_equals('Moby Dick', $book_map->{'title'});
		} else {
			#sayings of the century
			$self->assert_equals(8.95, $book_map->{'price'});
			$self->assert_equals('Sayings of the Century', $book_map->{'title'});
		}
	}

	$raw_result = $jp->run(\%test_structure, '$.store.*'); #book array and one bicycle
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(1, $#result);

	$raw_result = $jp->run(\%test_structure, '$.store..price'); #the price of everything
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(4, $#result);
	my %prices = (
		19.95 => undef,
		8.95 => undef,
		12.99 => undef,
		8.99 => undef,
		22.99 => undef
	);
	foreach my $price (@result){
		$self->assert(exists $prices{$price});
	}
	
	
	$raw_result = $jp->run(\%test_structure, '$..book[0,1]'); # the first two books
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(1, $#result);


	$raw_result = $jp->run(\%test_structure, '$..book[:2]'); # the first two books
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(1, $#result);

	$raw_result = $jp->run(\%test_structure, '$..book[-1:]'); # the last book
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(0, $#result);



	$raw_result = $jp->run(\%test_structure, '$..book[?(@.isbn)]'); #the price of everything
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(1, $#result);

	$raw_result = $jp->run(\%test_structure, '$.store.!'); #the keys in the store hash 
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(1, $#result);

#The $..* path appears to work just fine, I'm just unsure as to how best to test it...
#
#	$raw_result = $jp->run(\%test_structure, '$..*'); #the price of everything
#	$self->assert($raw_result != 0);
#	@result = @{$raw_result};
#	$self->assert_equals(1, $#result);


}

sub test_path_operations(){
	my $self = shift;
	my $jp = JSONPath->new();
	my $raw_result = undef;
	my @result = undef;

	$raw_result = $jp->run(\%test_structure, '$..author', {'result_type' => 'PATH'});
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(3, $#result);

	$self->assert_equals("[\"store\"][\"book\"][0][\"author\"]", $result[0]);
	$self->assert_equals("[\"store\"][\"book\"][1][\"author\"]", $result[1]);
	$self->assert_equals("[\"store\"][\"book\"][2][\"author\"]", $result[2]);
	$self->assert_equals("[\"store\"][\"book\"][3][\"author\"]", $result[3]);


	$raw_result = $jp->run(\%test_structure, '$.store.!', {'result_type' => 'PATH'});
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(1, $#result);

	$self->assert_equals("[\"store\"]", $result[0]);
	$self->assert_equals("[\"store\"]", $result[1]);
}

sub test_includes_test(){
	my $self = shift;
	my $jp = JSONPath->new();
	my $raw_result = undef;
	my @result = undef;

	$raw_result = $jp->run(\%test_structure, "\$..book[?(@.ratings><'good')]");
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
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(0, $#result);
	$raw_result = $jp->run(\%test_structure, "\$..ratings[?(@.><'good')]");
		#[
		#   [
		#      "good",
		#      "bad",
		#      "lovely"
		#   ]
		#]
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(0, $#result);
	$self->assert_equals('bad', $result[0][1]);


	$raw_result = $jp->run(\%test_structure, "\$..book[?(@.ratings><3)]");
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
	$self->assert($raw_result != 0);
	@result = @{$raw_result};
	$self->assert_equals(0, $#result);
	$self->assert_equals('reference', $result[0]{'category'});
	$self->assert_equals('ARRAY', ref $result[0]{'ratings'});
	$self->assert_equals(2, $result[0]{'ratings'}[2]);
#
#
}
return 1;
