#!/usr/bin/perl

# PODNAME: jsonpath.pl

# ABSTRACT: Simple script to execute JSONPath expressions against JSON files

use strict;
use JSONPath;
use JSON::MaybeXS;

if ($#ARGV < 1){
	die "Requires 2 arguments: <path/to/json/file> <JSONPath expression> <optional: VALUE|PATH>.\n";
}
my $expression = $ARGV[1];
$expression =~ s/\\!/!/g;


my $raw_json = '';
open (ORIG, $ARGV[0]) or die "unable to open $ARGV[0] $!\n";
while (<ORIG>){
	$raw_json .= $_;
}
close(ORIG);

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

