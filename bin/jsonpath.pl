#!/usr/bin/perl

# PODNAME: jsonpath.pl

# ABSTRACT: Simple script to execute JSONPath expressions against JSON files

use strict;
use warnings;
use JSONPath;
use JSON::MaybeXS qw/to_json from_json/;
use Path::Tiny;

if ($#ARGV < 1){
	die "Requires 2 arguments: <path/to/json/file> <JSONPath expression> <optional: VALUE|PATH>.\n";
}
my $expression = $ARGV[1];
$expression =~ s/\\!/!/g;

my $raw_json = path($ARGV[0])->slurp_raw;

my $json_structure = from_json($raw_json);
my $jp = JSONPath->new();
my $raw_result = undef;
if ($#ARGV == 1){
	$raw_result = $jp->run($json_structure, $expression);
} else {
	$raw_result = $jp->run($json_structure, $expression, {'result_type' => $ARGV[2]});
}

if ($raw_result){
	print to_json($raw_result, {utf8 => 1, pretty => 1}) . "\n";
} else {
	print "NO RESULTS.\n";
} 

