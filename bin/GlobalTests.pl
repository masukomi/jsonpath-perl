#!/usr/bin/perl
package GlobalTests;

use strict;
use lib '../lib', '../tests';

use Test::Unit::HarnessUnit;

### BEGIN Could be broken out into separate module
use base qw/Test::Unit::TestSuite/;

sub include_tests {
	return(
			'JSONPathTest'
 );
}
### END Could be broken out

my $testrunner = Test::Unit::HarnessUnit->new();
$testrunner->start("GlobalTests");


