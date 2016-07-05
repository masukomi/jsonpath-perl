# NAME

JSONPath - A port of the JavaScript and PHP versions of JSONPath [http://goessner.net/articles/JsonPath/](http://goessner.net/articles/JsonPath/)

# VERSION

version 0.81

# SYNOPSIS

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

# METHODS

## run

Evaluate a JSONPath expression on the given (parsed) JSON object.

Usage:
    $jp->run( $json\_object, $expression, \[ \\%options \] );

Currently supported options are `result_type`, which may be PATH or VALUE. PATH returns JSONPath 
expressions for each object matching the expression. VALUE returns the value of each matching 
object.

## normalize

normalize the path expression

# ABOUT JSONPath

JSONPath is the brainchild of [Stephan Goessner](http://goessner.net/). It takes the basic concept 
of XPATH and, using similar syntax, applies it to JSON data structures. This documentation is taken 
directly from [Stephan's JSONPath page](http://goessner.net/articles/JsonPath/) with minor tweaks 
specific to the Perl port. You can find the JavaScript, PHP, and C# implementation of it on the 
[JSONPath page at Google Code](http://code.google.com/p/jsonpath/).

JSONPath is distributed under the MIT License.

## JSONPath expressions

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

JSONPath allows the wildcard symbol \* for member names and array indices. It borrows the descendant 
operator '..' from E4X and the array slice syntax proposal `[start:end:step]` from ECMASCRIPT 4.

Expressions of the underlying scripting language () can be used as an alternative to explicit names 
or indices as in

    $.store.book[(@.length-1)].title

using the symbol '@' for the current object. Filter expressions are supported via the syntax ?() as 
in

    $.store.book[?(@.price < 10)].title

XPath has a lot more to offer (Location paths in not abbreviated syntax, operators and functions) 
than listed here. Moreover there is a remarkable difference how the subscript operator works in 
Xpath and JSONPath.

- Square brackets in XPath expressions always operate on the node set resulting from the previous path fragment. Indices always start by 1.
- With JSONPath square brackets operate on the object or array addressed by the previous path fragment. Indices always start by 0. 

## JSONPath Examples

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

## JSONPath Implementation

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
supported option is "result\_type" which can be "VALUE" or "PATH".

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

# ISSUES

- Currently only single quotes allowed inside of JSONPath expressions.
- Script expressions inside of JSONPath locations are currently not recursively evaluated by jsonPath. Only the global $ and local @ symbols are expanded by a simple regular expression.
- An alternative for jsonPath to return false in case of no match may be to return an empty array in future.

# AUTHOR

Kay Rhodes <masukomi@masukomi.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2016 by Kay Rhodes.

This is free software, licensed under:

    The MIT (X11) License
