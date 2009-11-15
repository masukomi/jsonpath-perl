#!/usr/bin/perl

#	JSONPath 0.8.1 - XPath for JSON
#	
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
use strict;
use lib '../../lib';
use JSON;
use Scalar::Util qw(looks_like_number);


sub new(){
	my $class = shift;
	my $self = bless {
		obj => undef,
		result_type => 'VALUE',
		result => [],
		subx => [],
		reserved_locs => {
			'*' => undef,
			'..' => undef,
		}
	}, $class;
	return $self;

}

sub run(){
	my $self = shift;
	$self->{'result'} = (); #reset it
	$self->{'obj'} = undef;
	my ($obj, $expr, $arg) = @_;
	#my $self->{'obj'} = $obj;
	#$self->logit( "arg: $arg");
	if ($arg && $arg->{'result_type'}){
		my $result_type = $arg->{'result_type'};
		if ($result_type eq 'PATH' | $result_type eq 'VALUE'){
			$self->{'result_type'} = $arg->{'result_type'};
		}
	}
	if ($expr and $obj and ($self->{'result_type'} eq 'VALUE' || $self->{'result_type'} eq 'PATH')){
		my $cleaned_expr = $self->normalize($expr);
		$cleaned_expr =~ s/^\$;//;
		$self->trace($cleaned_expr, $obj, '$');
		my @result = @{$self->{'result'}};
		
		#print STDERR " ending. result = @result\n";

		if ($#result > -1){
			#print STDERR " will return result\n";
			return \@result;
		} 
		#print STDERR "will return zero\n";
		return 0;
	}
}



=nd 
normalize the path expression;

=cut
sub normalize (){
	my $self = shift;
	my $x = shift;
	$x =~ s/"\/[\['](\??\(.*?\))[\]']\/"/&_callback_01($1)/eg;
	$x =~ s/'?(?<!@|\d)\.'?|\['?/;/g; 	#added the negative lookbehind -krhodes
										# added \d in it to compensate when 
										# comparinig against decimal numbers
	$x =~ s/;;;|;;/;..;/g;
	$x =~ s/;$|'?\]|'$//g;
	$x =~ s/#([0-9]+)/&_callback_02($1)/eg;
	$self->{'result'} = [];
	return $x;
}


sub as_path(){
	my $self = shift;
	my $path = shift;
	
	my @x = split(/;/, $path);
	my $p = '';
	#the JS and PHP versions of this are totally whack
	#foreach my $piece (@x){
	for(my $i =1; $i <= $#x; $i++){
		my $piece = $x[$i];
		if ($piece =~ m/^\d+$/){
			$p .= "[$piece]";
		} else {
			$p .= "[\"$piece\"]";
		}
	}
	return $p;
}

sub store(){
	my $self = shift;
	my $path = shift;
	my $object = shift;
	if ($path){
		if ($self->{'result_type'} eq 'PATH'){
			push @{$self->{'result'}}, $self->as_path($path);
		} else {
			push @{$self->{'result'}}, $object;
		}
	}
	#print STDERR "-Updated Result to: \n";
	foreach my $res (@{$self->{'result'}}){
		#print STDERR "-- $res\n";
	} 
	
	return $path;
}

sub trace(){
	#$self->logit( "raw trace args: @_");
	my $self = shift;
	my ($expr, $obj, $path) = @_;
	#$self->logit( "in trace. $expr /// $obj /// $path");
	if ($expr){
		my @x = split(/;/, $expr);
		my $loc = shift(@x);
		my $x_string = join(';', @x);
		#$self->logit("trace... expr: $expr x_string: $x_string");
		my $ref_type = ref $obj;
		my $reserved_loc = 0;
		if (exists $self->{'reserved_locs'}->{$loc}){
			$reserved_loc = 1;
		}
		
		#$self->logit("loc: $loc  // $reserved_loc // $ref_type");
		
		if (! $reserved_loc and  $ref_type eq 'HASH' and ($obj and exists $obj->{$loc}) ){ 
			#$self->logit( "tracing loc($loc) obj (hash)?");
			$self->trace($x_string, $obj->{$loc}, $path . ';' . $loc);
		} elsif (! $reserved_loc and $ref_type eq 'ARRAY' and ($loc =~ m/^\d+$/ and  $#{$obj} >= $loc and defined $obj->[$loc])   ) {
			$self->trace($x_string, $obj->[$loc], $path . ';' . $loc);
			
		} elsif ($loc eq '*'){
			#$self->logit( "tracing *");
			$self->walk($loc, $x_string, $obj, $path, \&_callback_03);
		} elsif ($loc eq '!'){
			#$self->logit( "tracing !");
			$self->walk($loc, $x_string, $obj, $path, \&_callback_06);
		} elsif ($loc eq '..'){
			#$self->logit( "tracing ..");
			$self->trace($x_string, $obj, $path);
			$self->walk($loc, $x_string, $obj, $path, \&_callback_04);
		} elsif ($loc =~ /,/){
			#$self->logit( "tracing loc w comma");
			foreach my $piece ( split(/'?,'?/, $loc)){
				$self->trace($piece . ';' . $x_string, $obj, $path);
			}
		} elsif ($loc =~ /^\(.*?\)$/){
			#$self->logit( "tracing loc /^\(.*?\)\$/");
			my $path_end = $path;
			$path_end =~ s/.*;(.).*?$/$1/;
			#WTF is eobjuate?!
			$self->trace($self->eobjuate($loc, $obj, $path_end . ';' . $x_string, $obj, $path));
		} elsif ($loc =~ /^\?\(.*?\)$/){
			#$self->logit( "tracing loc /^\?\(.*?\)\$/");
			$self->walk($loc, $x_string, $obj, $path, \&_callback_05);
			#$self->logit( "after walk w/ 05");
		} elsif ($loc =~ /^(-?[0-9]*):(-?[0-9]*):?([0-9]*)$/){
			#$self->logit( "tracing loc ($loc) for slice");
			$self->slice($loc, $x_string, $obj, $path);
		} elsif (! $loc and $ref_type eq 'ARRAY'){
			$self->store($path, $obj);
		}
	} else {
		#$self->logit( "trace no expr. will store $obj");
		$self->store($path, $obj);
	}
	#$self->logit( "leaving trace");
}

sub walk (){
	my $self = shift;
	my ($loc, $expr, $obj, $path, $funct) = @_;
	#$self->logit( "in walk. $loc /// $expr /// $obj /// $path ");
	
	if (ref $obj eq 'ARRAY'){
		
		for (my $i = 0; $i <= $#{$obj}; $i++){
			#$self->logit( "before Array func call: w/ $i /// $loc /// $expr /// $obj /// $path");
			$funct->($self, $i, $loc, $expr, $obj, $path); 
			#$self->logit( "after func call");
			
		}
	} elsif (ref $obj eq 'HASH') { # a Hash 
		my @keys = keys %{$obj};
		#print STDERR "$#keys keys in hash to iterate over:\n";
		foreach my $key (@keys){
			#$self->logit( "before Hash func call: w/ $key /// $loc /// $expr /// $obj /// $path");
			$funct->($self, $key, $loc, $expr, $obj, $path); 
			#$self->logit( "after func call");
		}
				
	}
	#$self->logit( " leaving walk");
}

sub slice(){
	my $self = shift;
	my ($loc, $expr, $obj, $path) = @_;
	$loc =~ s/^(-?[0-9]*):(-?[0-9]*):?(-?[0-9]*)$/$1:$2:$3/;
	# $3 would be if you wanted to specify the steps between the start and end.
	
	
	my @s = split (/:|,/,  $loc);
	
	my $len = 0;
	if (ref $obj eq 'HASH'){
		$len = $#{keys %{$obj}};
	} else { #array
		$len = $#{$obj};
	}
	my $start = $s[0] ? $s[0] : 0;
	my $end = undef;
	if ($loc !~ m/^:(\d+):?$/){
		$end = $s[1] ? $s[1] : $len; 
	} else {
		$end = int($s[1]) -1;
	}
	
	my $step = $s[2] ? $s[2] : 1;
	#$start = $start < 0 ? ($start + $len > 0 ? $start + $len : 0) : ($len > $start ? $start : $len);
	if ($start < 0){
		$start =  $len > 0 ? $start + $len +1: 0 ; 
		#the +1 is so that -1 gets us the last entry, -2 gets us the last two, etc...
	}
	$end = $end < 0 ? ($end + $len > 0 ? $end + $len : 0) : ($len > $end ? $end : $len); 
	#$self->logit("start: $start end: $end step: $step");
	for (my $x = $start; $x <= $end; $x += $step){
		$self->trace("$x;$expr", $obj, $path);
	}
}

sub evalx(){
	my $self = shift;
	my ($loc, $obj) = @_;
	#$self->logit( "in evalx: $loc /// $obj");
	#x: @.price<10: [object Object] _vname: 0
	#need to convert @.price<10 to 
	#$obj->{'price'} < 10
	#and then evaluate
	#
	#x: @.isbn
	#needs to convert to 
	#exists $obj->{'isbn'}
	
	if ($loc =~ m/^@\.[a-zA-Z0-9_-]*$/){
		#$self->logit( "existence test ");
		$loc =~ s/@\.([a-zA-Z0-9_-]*)$/exists \$obj->{'$1'}/;
	} else { # it's a comparis on some sort?
		my $obj_type = ref($obj);
		$loc =~ s/@\.([a-zA-Z0-9_-]*)(.*)/\$obj->{'$1'}$2/;
		$loc =~ s/(?<!=)(=)(?!=)/==/; #convert single equals to double
		if ($loc =~ m/\s*(!|=)=['"](.*?)['"]/){
			$loc =~ s/\s*==['"](.*?)['"]/ eq "$1"/;
			$loc =~ s/\s*!=['"](.*?)['"]/ ne "$1"/;
			my $string_match = 0;
			if ($loc =~ m/ (eq|ne) /){ #dunno if those replacements happened...
				$string_match =1;
			}
			#$self->logit( "comparison test of  $1 and $2 ::loc:: $loc");
			if ($obj_type ne 'HASH' and $obj_type ne 'ARRAY' and $obj){
				if (! $string_match){
					$loc =~s/\$obj->{(.*?)}(.*)/$obj $2/;
				} else {
					$loc =~s/\$obj->{(.*?)}(.*)/"$obj" $2/;
				}
				return ($obj and $loc and eval($loc)) ? 1 : 0;
			} 
		} elsif ($loc =~ m/></){
			my $query_item = $loc;
			$query_item =~ s/.*><\s*['"]?([\w\.]*)['"]?\s*/$1/;
			#$self->logit("includes test: $query_item :: $loc ::");
			if (($obj_type eq 'HASH' or $obj_type eq 'ARRAY')){
				#$self->logit("hash or array");
				if ($obj_type eq 'HASH'){
					#something like "$..book[?(@.ratings><'good')]"
					#obj is book
					my $eval_string = $loc;
					my $sub_obj = undef;
					$eval_string =~ s/(.*?)><.*/$1/;
					#$eval_string =~ s/(.*?)><.*/\$sub_obj_type = ref $1\->{'$query_item'}/;
					#$self->logit("eval_string: $eval_string");
					#set the sub_obj_type
					eval('$sub_obj = ' . $eval_string);
					my $sub_obj_type =ref $sub_obj;
					#$self->logit("sub_obj_type: $sub_obj_type");
					if ($sub_obj){
						if ($sub_obj_type eq 'ARRAY'){
							foreach my $item (@{$sub_obj}){
								if (looks_like_number($item)){
									return 1 if $item == $query_item;
								}else {
									return 1 if $item eq $query_item;
								}
							}
							return 0;
						} elsif ($sub_obj_type eq 'HASH'){
							return exists ($sub_obj->{$query_item}) ? 1 : 0;
						}  
					} else {
						#$self->logit("no sub_obj");
					}
				}
			} else {
				#$self->logit(" in array item evalling");
				my $returnable = 0;
				if (! looks_like_number($obj)){
					#Does the string include the string they've provided?
					#return ($obj eq $query_item or $obj =~ m/.*?$query_item.*?/) ? 1 : 0;
					$returnable =  ($obj eq $query_item or $obj =~ m/.*?$query_item.*?/) ? 1 : 0;
				} else {
					#return $obj == $query_item;
					$returnable = ($obj == $query_item) ? 1 : 0;
				}
				#not the best use of the >< operator. we've been drilled down to
				#
				#$self->logit("returning $returnable");
				return $returnable;
			}
		} else {
			#$self->logit("loc not equality or includes test: $loc");
		}
	}
	#print STDERR "loc: $loc\n";
	return ($obj and $loc and eval($loc)) ? 1 : 0;
}

sub _callback_01(){
	my $self = shift;
	#$self->logit( "in 01");
	my $arg = shift;
	push @{$self->{'result'}}, $arg;
	return '[#' . $#{$self->{'result'}} . ']';
}

sub _callback_02 {
	my $self = shift;
	#$self->logit( "in 02");
	my $arg = shift;
	return @{$self->{'result'}}[$arg];
}


sub _callback_03(){
	my $self = shift;
	#$self->logit( " in 03 ");
	my ($key, $loc, $expr, $obj, $path) = @_;
	$self ->trace($key . ';' . $expr , $obj, $path);
}

sub _callback_04(){
	my $self = shift;
	my ($key, $loc, $expr, $obj, $path) = @_;
	#$self->logit( " in 04. expr = $expr");
	if (ref $obj eq 'HASH'){
		if (ref($obj->{$key}) eq 'HASH' ){
			#$self->logit( "Passing this to trace: ..;$expr, " . $obj->{$key} . ", $path;$key\n";
			$self->trace('..;'.$expr, $obj->{$key}, $path . ';' . $key);
		} elsif (ref($obj->{$key})) { #array
			#print STDERR "--- \$obj->{$key} wasn't a hash. it was a " . (ref $obj->{$key}) . "\n";
			$self->trace('..;'.$expr, $obj->{$key}, $path . ';' . $key);
		}
	} else {
		#print STDERR "-- obj wasn't a hash. it was a " . (ref $obj) . "\n";
		if (ref($obj->[$key]) eq 'HASH' ){
			$self->trace('..;'.$expr, $obj->[$key], $path . ';' . $key);
		}
	}

}

sub _callback_05(){
	my $self = shift;
	#$self->logit( "05");
	my ($key, $loc, $expr, $obj, $path) = @_;
	$loc =~ s/^\?\((.*?)\)$/$1/;
	my $eval_result = 0;
	if (ref $obj eq 'HASH'){
		#$self->logit( " in 05 obj: $obj obj->{$key}: ". $obj->{$key});
		$eval_result = $self->evalx($loc, $obj->{$key});
	} else {
		#$self->logit( " in 05 obj: $obj obj->[$key]: ". $obj->[$key] );
		$eval_result = $self->evalx($loc, $obj->[$key]);
	}
	#$self->logit( "eval_result: $eval_result"); 
	if ($eval_result){
		#$self->logit("IT EVALLED! tracing..");
		$self->trace("$key;$expr", $obj, $path);
	}
	#$self->logit( "leaving 05");
}

sub _callback_06(){
	my $self = shift;
	my ($key, $loc, $expr, $obj, $path) = @_;
	#$self->logit("in 06 $key /// $loc /// $expr /// $obj /// $path" );
	if (ref $obj eq 'HASH'){
		$self->trace($expr, $key, $path);
	}
}

my $log_count = 1;
sub logit(){
	my $self = shift;
	my $message = shift;
	print STDERR "$log_count) $message\n";
	$log_count++;
}

return 1;


