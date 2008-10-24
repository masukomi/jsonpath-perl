package JSON::PP;

# JSON-2.0

use 5.005;
use strict;
use base qw(Exporter);
use overload;

use Carp ();
use B ();
#use Devel::Peek;

$JSON::PP::VERSION = '2.06';

@JSON::PP::EXPORT = qw(encode_json decode_json from_json to_json);

# instead of hash-access, i tried index-access for speed.
# but this method is not faster than what i expected. so it will be changed.

use constant P_ASCII                => 0;
use constant P_LATIN1               => 1;
use constant P_UTF8                 => 2;
use constant P_INDENT               => 3;
use constant P_CANONICAL            => 4;
use constant P_SPACE_BEFORE         => 5;
use constant P_SPACE_AFTER          => 6;
use constant P_ALLOW_NONREF         => 7;
use constant P_SHRINK               => 8;
use constant P_ALLOW_BLESSED        => 9;
use constant P_CONVERT_BLESSED      => 10;
use constant P_RELAXED              => 11;

use constant P_LOOSE                => 12;
use constant P_ALLOW_BIGNUM         => 13;
use constant P_ALLOW_BAREKEY        => 14;
use constant P_ALLOW_SINGLEQUOTE    => 15;
use constant P_ESCAPE_SLASH         => 16;
use constant P_AS_NONBLESSED        => 17;


BEGIN {
    my @xs_compati_bit_properties = qw(
            utf8 indent canonical space_before space_after allow_nonref shrink
            allow_blessed convert_blessed relaxed
    );
    my @pp_bit_properties = qw(
            allow_singlequote allow_bignum loose
            allow_barekey escape_slash as_nonblessed
    );

    # Perl version check, ascii() is enable?
    # Helper module may set @JSON::PP::_properties.

    if ($] >= 5.008) {
        push @xs_compati_bit_properties, 'ascii', 'latin1';

        if ($] == 5.008) {
           require Encode;
           *utf8::is_utf8 = *Encode::is_utf8;
        }

        *JSON_PP_encode_ascii      = *_encode_ascii;
        *JSON_PP_encode_latin1     = *_encode_latin1;
        *JSON_PP_decode_surrogates = *_decode_surrogates;
        *JSON_PP_decode_unicode    = *_decode_unicode;
    }
    else {
        my $helper = $] >= 5.006 ? 'JSON::PP56' : 'JSON::PP5005';
        eval qq| require $helper |;
        if ($@) { Carp::croak $@; }
        push @xs_compati_bit_properties, @JSON::PP::_properties;
    }

    for my $name (@xs_compati_bit_properties, @pp_bit_properties) {
        my $flag_name = 'P_' . uc($name);

        eval qq/
            sub $name {
                my \$enable = defined \$_[1] ? \$_[1] : 1;

                if (\$enable) {
                    \$_[0]->{PROPS}->[$flag_name] = 1;
                }
                else {
                    \$_[0]->{PROPS}->[$flag_name] = 0;
                }

                \$_[0];
            }

            sub get_$name {
                \$_[0]->{PROPS}->[$flag_name] ? 1 : '';
            }
        /;
    }

    if ($] >= 5.008 and $] < 5.008003) { # join() in 5.8.0 - 5.8.2 is broken.
        require subs;
        subs->import('join');
        eval q|
            sub join {
                return '' if (@_ < 2);
                my $j   = shift;
                my $str = shift;
                for (@_) { $str .= $j . $_; }
                return $str;
            }
        |;
    }

}



# Functions

my %encode_allow_method
     = map {($_ => 1)} qw/utf8 pretty allow_nonref latin1 self_encode escape_slash
                          allow_blessed convert_blessed indent indent_length allow_bignum
                          as_nonblessed
                        /;
my %decode_allow_method
     = map {($_ => 1)} qw/utf8 allow_nonref loose allow_singlequote allow_bignum
                          allow_barekey max_size relaxed/;


my $JSON; # cache

sub encode_json ($) { # encode
    ($JSON ||= __PACKAGE__->new->utf8)->encode(@_);
}


sub decode_json { # decode
    ($JSON ||= __PACKAGE__->new->utf8)->decode(@_);
}

# Obsoleted

sub to_json($) {
   Carp::croak ("JSON::PP::to_json has been renamed to encode_json.");
}


sub from_json($) {
   Carp::croak ("JSON::PP::from_json has been renamed to decode_json.");
}


# Methods

sub new {
    my $class = shift;
    my $self  = {
        max_depth   => 512,
        max_size    => 1,
        indent      => 0,
        FLAGS       => 0,
        fallback      => sub { encode_error('Invalid value. JSON can only reference.') },
        indent_length => 3,
    };

    bless $self, $class;
}


sub encode {
    return $_[0]->PP_encode_json($_[1]);
}


sub decode {
    return $_[0]->PP_decode_json($_[1], 0x00000000);
}


sub decode_prefix {
    return $_[0]->PP_decode_json($_[1], 0x00000001);
}


# accessor


# pretty printing

sub pretty {
    my ($self, $v) = @_;
    my $enable = defined $v ? $v : 1;

    if ($enable) { # indent_length(3) for JSON::XS compatibility
        $self->indent(1)->indent_length(3)->space_before(1)->space_after(1);
    }
    else {
        $self->indent(0)->space_before(0)->space_after(0);
    }

    $self;
}

# etc

sub max_depth {
    my $max  = defined $_[1] ? $_[1] : 0x80000000;
    my $log2 = 0;
    if ($max > 0x80000000) { $max = 0x80000000; }
    while ((1 << $log2) < $max) {
        ++$log2;
    }
    $_[0]->{max_depth} = 1 << $log2;
    $_[0];
}

sub get_max_depth { $_[0]->{max_depth}; }

sub max_size {
    my $max  = defined $_[1] ? $_[1] : 0;
    my $log2 = 0;
    if ($max > 0x80000000) { $max = 0x80000000; }
    if ($max == 1)         { $max = 2; }
    while ((1 << $log2) < $max) {
        ++$log2;
    }
    $_[0]->{max_size} = 1 << $log2;
    $_[0];
}

sub get_max_size { $_[0]->{max_size}; }

sub filter_json_object {
    $_[0]->{cb_object} = defined $_[1] ? $_[1] : 0;
    $_[0]->{F_HOOK} = ($_[0]->{cb_object} or $_[0]->{cb_sk_object}) ? 1 : 0;
    $_[0];
}

sub filter_json_single_key_object {
    if (@_ > 1) {
        $_[0]->{cb_sk_object}->{$_[1]} = $_[2];
    }
    $_[0]->{F_HOOK} = ($_[0]->{cb_object} or $_[0]->{cb_sk_object}) ? 1 : 0;
    $_[0];
}

sub indent_length {
    if (!defined $_[1] or $_[1] > 15 or $_[1] < 0) {
        Carp::carp "The acceptable range of indent_length() is 0 to 15.";
    }
    else {
        $_[0]->{indent_length} = $_[1];
    }
    $_[0];
}

sub get_indent_length {
    $_[0]->{indent_length};
}

sub sort_by {
    $_[0]->{sort_by} = defined $_[1] ? $_[1] : 1;
    $_[0];
}

sub allow_bigint {
    Carp::carp("allow_bigint() is obsoleted. use allow_bignum() insted.");
}

###############################

###
### Perl => JSON
###


{ # Convert

    my $max_depth;
    my $indent;
    my $ascii;
    my $latin1;
    my $utf8;
    my $space_before;
    my $space_after;
    my $canonical;
    my $allow_blessed;
    my $convert_blessed;

    my $indent_length;
    my $escape_slash;
    my $bignum;
    my $as_nonblessed;

    my $depth;
    my $indent_count;
    my $keysort;


    sub PP_encode_json {
        my $self = shift;
        my $obj  = shift;

        $indent_count = 0;
        $depth        = 0;

        my $idx = $self->{PROPS};

        ($ascii, $latin1, $utf8, $indent, $canonical, $space_before, $space_after, $allow_blessed,
            $convert_blessed, $escape_slash, $bignum, $as_nonblessed)
         = @{$idx}[P_ASCII .. P_SPACE_AFTER, P_ALLOW_BLESSED, P_CONVERT_BLESSED,
                    P_ESCAPE_SLASH, P_ALLOW_BIGNUM, P_AS_NONBLESSED];

        ($max_depth, $indent_length) = @{$self}{qw/max_depth indent_length/};

        $keysort = $canonical ? sub { $a cmp $b } : undef;

        if ($self->{sort_by}) {
            $keysort = ref($self->{sort_by}) eq 'CODE' ? $self->{sort_by}
                     : $self->{sort_by} =~ /\D+/       ? $self->{sort_by}
                     : sub { $a cmp $b };
        }

        encode_error("hash- or arrayref expected (not a simple scalar, use allow_nonref to allow this)")
             if(!ref $obj and !$idx->[ P_ALLOW_NONREF ]);

        my $str  = $self->object_to_json($obj);

        unless ($ascii or $latin1 or $utf8) {
            utf8::upgrade($str);
        }

        if ($idx->[ P_SHRINK ]) {
            utf8::downgrade($str, 1);
        }

        return $str;
    }


    sub object_to_json {
        my ($self, $obj) = @_;
        my $type = ref($obj);

        if($type eq 'HASH'){
            return $self->hash_to_json($obj);
        }
        elsif($type eq 'ARRAY'){
            return $self->array_to_json($obj);
        }
        elsif ($type) { # blessed object?
            if (blessed($obj)) {

                return $self->value_to_json($obj) if ( $obj->isa('JSON::PP::Boolean') );
                return $self->object_to_json( $obj->TO_JSON() )
                    if ( $convert_blessed and $obj->can('TO_JSON') );
                return "$obj" if ( $bignum and _is_bignum($obj) );
                return $self->blessed_to_json($obj) if ($allow_blessed and $as_nonblessed);

                encode_error( sprintf("encountered object '%s', but neither allow_blessed "
                    . "nor convert_blessed settings are enabled", $obj)
                ) unless ($allow_blessed);

                return 'null';
            }
            else {
                return $self->value_to_json($obj);
            }
        }
        else{
            return $self->value_to_json($obj);
        }
    }


    sub hash_to_json {
        my ($self, $obj) = @_;
        my ($k,$v);
        my %res;

        encode_error("data structure too deep (hit recursion limit)")
                                         if (++$depth > $max_depth);

        my ($pre, $post) = $indent ? $self->_up_indent() : ('', '');
        my $del = ($space_before ? ' ' : '') . ':' . ($space_after ? ' ' : '');

        if ( my $tie_class = tied %$obj ) {
            if ( $tie_class->can('TIEHASH') ) {
                $tie_class =~ s/=.+$//;
                tie %res, $tie_class;
            }
        }

        # In the old Perl verions, tied hashes in bool context didn't work.
        # So, we can't use such a way (%res ? a : b)
        my $has;

        for my $k (keys %$obj) {
            my $v = $obj->{$k};
            $res{$k} = $self->object_to_json($v) || $self->value_to_json($v);
            $has = 1 unless ( $has );
        }

        --$depth;
        $self->_down_indent() if ($indent);

        return '{' . ( $has ? $pre : '' )                                                   # indent
                   . ( $has ? join(",$pre", map { utf8::decode($_) if ($] < 5.008);         # key for Perl 5.6
                                                string_to_json($self, $_) . $del . $res{$_} # key : value
                                            } _sort( $self, \%res )
                             ) . $post                                                      # indent
                           : ''
                     )
             . '}';
    }


    sub array_to_json {
        my ($self, $obj) = @_;
        my @res;

        encode_error("data structure too deep (hit recursion limit)")
                                         if (++$depth > $max_depth);

        my ($pre, $post) = $indent ? $self->_up_indent() : ('', '');

        if (my $tie_class = tied @$obj) {
            if ( $tie_class->can('TIEARRAY') ) {
                $tie_class =~ s/=.+$//;
                tie @res, $tie_class;
            }
        }

        for my $v (@$obj){
            push @res, $self->object_to_json($v) || $self->value_to_json($v);
        }

        --$depth;
        $self->_down_indent() if ($indent);

        return '[' . ( @res ? $pre : '' ) . ( @res ? join( ",$pre", @res ) . $post : '' ) . ']';
    }


    sub value_to_json {
        my ($self, $value) = @_;

        return 'null' if(!defined $value);

        my $b_obj = B::svref_2object(\$value);  # for round trip problem
        my $flags = $b_obj->FLAGS;

        return $value # as is 
            if ( (    $flags & B::SVf_IOK or $flags & B::SVp_IOK
                   or $flags & B::SVf_NOK or $flags & B::SVp_NOK
                 ) and !($flags & B::SVf_POK )
            ); # SvTYPE is IV or NV?

        my $type = ref($value);

        if(!$type){
            return string_to_json($self, $value);
        }
        elsif( blessed($value) and  $value->isa('JSON::PP::Boolean') ){
            return $$value == 1 ? 'true' : 'false';
        }
        elsif ($type) {
            if ((overload::StrVal($value) =~ /=(\w+)/)[0]) {
                return $self->value_to_json("$value");
            }

            if ($type eq 'SCALAR' and defined $$value) {
                return   $$value eq '1' ? 'true'
                       : $$value eq '0' ? 'false' : encode_error("cannot encode reference.");
            }

            if ($type eq 'CODE') {
                encode_error("encountered $value, but JSON can only represent references to arrays or hashes");
            }
            else {
                encode_error("cannot encode reference.");
            }

        }
        else {
            return $self->{fallback}->($value)
                 if ($self->{fallback} and ref($self->{fallback}) eq 'CODE');
            return 'null';
        }

    }


    my %esc = (
        "\n" => '\n',
        "\r" => '\r',
        "\t" => '\t',
        "\f" => '\f',
        "\b" => '\b',
        "\"" => '\"',
        "\\" => '\\\\',
        "\'" => '\\\'',
    );


    sub string_to_json {
        my ($self, $arg) = @_;

        $arg =~ s/([\x22\x5c\n\r\t\f\b])/$esc{$1}/eg;
        $arg =~ s/\//\\\//g if ($escape_slash);
        $arg =~ s/([\x00-\x08\x0b\x0e-\x1f])/'\\u00' . unpack('H2', $1)/eg;

        if ($ascii) {
            $arg = JSON_PP_encode_ascii($arg);
        }

        if ($latin1) {
            $arg = JSON_PP_encode_latin1($arg);
        }

        if ($utf8) {
            utf8::encode($arg);
        }

        return '"' . $arg . '"';
    }


    sub blessed_to_json {
        my $b_obj = B::svref_2object($_[1]);
        if ($b_obj->isa('B::HV')) {
            return $_[0]->hash_to_json($_[1]);
        }
        elsif ($b_obj->isa('B::AV')) {
            return $_[0]->array_to_json($_[1]);
        }
        else {
            return 'null';
        }
    }


    sub encode_error {
        my $error  = shift;
        Carp::croak "$error";
    }


    sub _sort {
        my ($self, $res) = @_;
        defined $keysort ? (sort $keysort (keys %$res)) : keys %$res;
    }


    sub _up_indent {
        my $self  = shift;
        my $space = ' ' x $indent_length;

        my ($pre,$post) = ('','');

        $post = "\n" . $space x $indent_count;

        $indent_count++;

        $pre = "\n" . $space x $indent_count;

        return ($pre,$post);
    }


    sub _down_indent { $indent_count--; }


    sub PP_encode_box {
        {
            depth        => $depth,
            indent_count => $indent_count,
        };
    }

} # Convert


sub _encode_ascii {
    join('',
        map {
            $_ <= 127 ?
                chr($_) :
            $_ <= 65535 ?
                sprintf('\u%04x', $_) : sprintf('\u%x\u%x', _encode_surrogates($_));
        } unpack('U*', $_[0])
    );
}


sub _encode_latin1 {
    join('',
        map {
            $_ <= 255 ?
                chr($_) :
            $_ <= 65535 ?
                sprintf('\u%04x', $_) : sprintf('\u%x\u%x', _encode_surrogates($_));
        } unpack('U*', $_[0])
    );
}


sub _encode_surrogates { # from perlunicode
    my $uni = $_[0] - 0x10000;
    return ($uni / 0x400 + 0xD800, $uni % 0x400 + 0xDC00);
}


sub _is_bignum {
    $_[0]->isa('Math::BigInt') or $_[0]->isa('Math::BigFloat');
}



#
# JSON => Perl
#

my $max_intsize;

BEGIN {
    my $checkint = 1111;
    for my $d (5..30) {
        $checkint .= 1;
        my $int   = eval qq| $checkint |;
        if ($int =~ /[eE]/) {
            $max_intsize = $d - 1;
            last;
        }
    }
}

{ # PARSE 

    my %escapes = ( #  by Jeremy Muhlich <jmuhlich [at] bitflood.org>
        b    => "\x8",
        t    => "\x9",
        n    => "\xA",
        f    => "\xC",
        r    => "\xD",
        '\\' => '\\',
        '"'  => '"',
        '/'  => '/',
    );

    my $text; # json data
    my $at;   # offset
    my $ch;   # 1chracter
    my $len;  # text length (changed according to UTF8 or NON UTF8)
    # INTERNAL
    my $is_utf8;        # must be with UTF8 flag
    my $depth;          # nest counter
    my $encoding;       # json text encoding
    my $is_valid_utf8;  # temp variable
    my $utf8_len;       # utf8 byte length
    # FLAGS
    my $utf8;           # must be utf8
    my $max_depth;      # max nest nubmer of objects and arrays
    my $max_size;
    my $relaxed;
    my $cb_object;
    my $cb_sk_object;

    my $F_HOOK;

    my $allow_bigint;   # using Math::BigInt
    my $singlequote;    # loosely quoting
    my $loose;          # 
    my $allow_barekey;  # bareKey

    # $opt flag
    # 0x00000001 .... decode_prefix

    sub PP_decode_json {
        my ($self, $opt); # $opt is an effective flag during this decode_json.

        ($self, $text, $opt) = @_;

        ($at, $ch, $depth) = (0, '', 0);

        if (!defined $text or ref $text) {
            decode_error("malformed text data.");
        }

        my $idx = $self->{PROPS};

        ($utf8, $relaxed, $loose, $allow_bigint, $allow_barekey, $singlequote)
            = @{$idx}[P_UTF8, P_RELAXED, P_LOOSE .. P_ALLOW_SINGLEQUOTE];

        $is_utf8 = 1 if ( $utf8 or utf8::is_utf8( $text ) );

        if ( $utf8 ) {
            utf8::downgrade( $text, 1 ) or Carp::croak("Wide character in subroutine entry");
        }
        else {
            utf8::upgrade( $text );
        }

        $len = length $text;

        ($max_depth, $max_size, $cb_object, $cb_sk_object, $F_HOOK)
             = @{$self}{qw/max_depth  max_size cb_object cb_sk_object F_HOOK/};

        if ($max_size > 1) {
            use bytes;
            my $bytes = length $text;
            decode_error(
                sprintf("attempted decode of JSON text of %s bytes size, but max_size is set to %s"
                    , $bytes, $max_size), 1
            ) if ($bytes > $max_size);
        }

        # Currently no effect
        my @octets = unpack('C4', $text);
        $encoding =   ( $octets[0] and  $octets[1]) ? 'UTF-8'
                    : (!$octets[0] and  $octets[1]) ? 'UTF-16BE'
                    : (!$octets[0] and !$octets[1]) ? 'UTF-32BE'
                    : ( $octets[2]                ) ? 'UTF-16LE'
                    : (!$octets[2]                ) ? 'UTF-32LE'
                    : 'unknown';

        my $result = value();

        if (!$idx->[ P_ALLOW_NONREF ] and !ref $result) {
                decode_error(
                'JSON text must be an object or array (but found number, string, true, false or null,'
                       . ' use allow_nonref to allow this)', 1);
        }

        if ($len >= $at) {
            my $consumed = $at - 1;
            white();
            if ($ch) {
                decode_error("garbage after JSON object") unless ($opt & 0x00000001);
                return ($result, $consumed);
            }
        }

        $result;
    }


    sub next_chr {
        return $ch = undef if($at >= $len);
        $ch = substr($text, $at++, 1);
    }


    sub value {
        white();
        return          if(!defined $ch);
        return object() if($ch eq '{');
        return array()  if($ch eq '[');
        return string() if($ch eq '"' or ($singlequote and $ch eq "'"));
        return number() if($ch =~ /\d/ or $ch eq '-');
        return word();
    }

    sub string {
        my ($i, $s, $t, $u);
        my $utf16;

        ($is_valid_utf8, $utf8_len) = ('', 0);

        $s = ''; # basically UTF8 flag on

        if($ch eq '"' or ($singlequote and $ch eq "'")){
            my $boundChar = $ch if ($singlequote);

            OUTER: while( defined(next_chr()) ){

                if((!$singlequote and $ch eq '"') or ($singlequote and $ch eq $boundChar)){
                    next_chr();

                    if ($utf16) {
                        decode_error("missing low surrogate character in surrogate pair");
                    }

                    utf8::decode($s) if($is_utf8);

                    return $s;
                }
                elsif($ch eq '\\'){
                    next_chr();
                    if(exists $escapes{$ch}){
                        $s .= $escapes{$ch};
                    }
                    elsif($ch eq 'u'){ # UNICODE handling
                        my $u = '';

                        for(1..4){
                            $ch = next_chr();
                            last OUTER if($ch !~ /[0-9a-fA-F]/);
                            $u .= $ch;
                        }

                        # U+D800 - U+DBFF
                        if ($u =~ /^[dD][89abAB][0-9a-fA-F]{2}/) { # UTF-16 high surrogate?
                            $utf16 = $u;
                        }
                        # U+DC00 - U+DFFF
                        elsif ($u =~ /^[dD][c-fC-F][0-9a-fA-F]{2}/) { # UTF-16 low surrogate?
                            unless (defined $utf16) {
                                decode_error("missing high surrogate character in surrogate pair");
                            }
                            $is_utf8 = 1;
                            $s .= JSON_PP_decode_surrogates($utf16, $u) || next;
                            $utf16 = undef;
                        }
                        else {
                            if (defined $utf16) {
                                decode_error("surrogate pair expected");
                            }

                            if ((my $hex = hex( $u )) > 255) {
                                $is_utf8 = 1;
                                $s .= JSON_PP_decode_unicode($u) || next;
                            }
                            else {
                                $s .= chr $hex;
                            }
                        }

                    }
                    else{
                        unless ($loose) {
                            decode_error('illegal backslash escape sequence in string');
                        }
                        $s .= $ch;
                    }
                }
                else{
                    if ($utf8) {
                        if( !is_valid_utf8($ch) ) {
                            $at -= $utf8_len;
                            decode_error("malformed UTF-8 character in JSON string");
                        }
                    }

                    if (!$loose) {
                        if ($ch =~ /[\x00-\x1f\x22\x5c]/)  { # '/' ok
                            $at--;
                            decode_error('invalid character encountered while parsing JSON string');
                        }
                    }

                    $s .= $ch;
                }
            }
        }

        decode_error("unexpected end of string while parsing JSON string");
    }


    sub white {
        while( defined $ch  ){
            if($ch le ' '){
                next_chr();
            }
            elsif($ch eq '/'){
                next_chr();
                if(defined $ch and $ch eq '/'){
                    1 while(defined(next_chr()) and $ch ne "\n" and $ch ne "\r");
                }
                elsif(defined $ch and $ch eq '*'){
                    next_chr();
                    while(1){
                        if(defined $ch){
                            if($ch eq '*'){
                                if(defined(next_chr()) and $ch eq '/'){
                                    next_chr();
                                    last;
                                }
                            }
                            else{
                                next_chr();
                            }
                        }
                        else{
                            decode_error("Unterminated comment");
                        }
                    }
                    next;
                }
                else{
                    $at--;
                    decode_error("malformed JSON string, neither array, object, number, string or atom");
                }
            }
            else{
                if ($relaxed and $ch eq '#') { # correctly?
                    pos($text) = $at;
                    $text =~ /\G([^\n]*(?:\r\n|\r|\n))/g;
                    $at = pos($text);
                    next_chr;
                    next;
                }

                last;
            }
        }
    }


    sub array {
        my $a  = [];

        decode_error('json datastructure exceeds maximum nesting level (set a higher max_depth)')
                                                    if (++$depth > $max_depth);

        next_chr();
        white();

        if(defined $ch and $ch eq ']'){
            --$depth;
            next_chr();
            return $a;
        }
        else {
            while(defined($ch)){
                push @$a, value();

                white();

                if (!defined $ch) {
                    last;
                }

                if($ch eq ']'){
                    --$depth;
                    next_chr();
                    return $a;
                }

                if($ch ne ','){
                    last;
                }

                next_chr();
                white();

                if ($relaxed and $ch eq ']') {
                    --$depth;
                    next_chr();
                    return $a;
                }

            }
        }

        decode_error(", or ] expected while parsing array");
    }


    sub object {
        my $o = {};
        my $k;

        decode_error('json datastructure exceeds maximum nesting level (set a higher max_depth)')
                                                if (++$depth > $max_depth);
        next_chr();
        white();

        if(defined $ch and $ch eq '}'){
            --$depth;
            next_chr();
            if ($F_HOOK) {
                return _json_object_hook($o);
            }
            return $o;
        }
        else {
            while(defined $ch){
                $k = ($allow_barekey and $ch ne '"' and $ch ne "'") ? bareKey() : string();
                white();

                if(!defined $ch or $ch ne ':'){
                    decode_error("Bad object ; ':' expected");
                }

                next_chr();
                $o->{$k} = value();
                white();

                last if (!defined $ch);

                if($ch eq '}'){
                    --$depth;
                    next_chr();
                    if ($F_HOOK) {
                        return _json_object_hook($o);
                    }
                    return $o;
                }

                if($ch ne ','){
                    last;
                }

                next_chr();
                white();

                if ($relaxed and $ch eq '}') {
                    --$depth;
                    next_chr();
                    if ($F_HOOK) {
                        return _json_object_hook($o);
                    }
                    return $o;
                }

            }

        }

        decode_error("Bad object ; ,or } expected while parsing object/hash");
    }


    sub bareKey { # doesn't strictly follow Standard ECMA-262 3rd Edition
        my $key;
        while($ch =~ /[^\x00-\x23\x25-\x2F\x3A-\x40\x5B-\x5E\x60\x7B-\x7F]/){
            $key .= $ch;
            next_chr();
        }
        return $key;
    }


    sub word {
        my $word =  substr($text,$at-1,4);

        if($word eq 'true'){
            $at += 3;
            next_chr;
            return $JSON::PP::true;
        }
        elsif($word eq 'null'){
            $at += 3;
            next_chr;
            return undef;
        }
        elsif($word eq 'fals'){
            $at += 3;
            if(substr($text,$at,1) eq 'e'){
                $at++;
                next_chr;
                return $JSON::PP::false;
            }
        }

        $at--; # for decode_error report

        decode_error("'null' expected")  if ($word =~ /^n/);
        decode_error("'true' expected")  if ($word =~ /^t/);
        decode_error("'false' expected") if ($word =~ /^f/);
        decode_error("malformed JSON string, neither array, object, number, string or atom");
    }


    sub number {
        my $n    = '';
        my $v;

        # According to RFC4627, hex or oct digts are invalid.
        if($ch eq '0'){
            my $peek = substr($text,$at,1);
            my $hex  = $peek =~ /[xX]/; # 0 or 1

            if($hex){
                decode_error("malformed number (leading zero must not be followed by another digit)");
                ($n) = ( substr($text, $at+1) =~ /^([0-9a-fA-F]+)/);
            }
            else{ # oct
                ($n) = ( substr($text, $at) =~ /^([0-7]+)/);
                if (defined $n and length $n > 1) {
                    decode_error("malformed number (leading zero must not be followed by another digit)");
                }
            }

            if(defined $n and length($n)){
                if (!$hex and length($n) == 1) {
                   decode_error("malformed number (leading zero must not be followed by another digit)");
                }
                $at += length($n) + $hex;
                next_chr;
                return $hex ? hex($n) : oct($n);
            }
        }

        if($ch eq '-'){
            $n = '-';
            next_chr;
            if (!defined $ch or $ch !~ /\d/) {
                decode_error("malformed number (no digits after initial minus)");
            }
        }

        while(defined $ch and $ch =~ /\d/){
            $n .= $ch;
            next_chr;
        }

        if(defined $ch and $ch eq '.'){
            $n .= '.';

            next_chr;
            if (!defined $ch or $ch !~ /\d/) {
                decode_error("malformed number (no digits after decimal point)");
            }
            else {
                $n .= $ch;
            }

            while(defined(next_chr) and $ch =~ /\d/){
                $n .= $ch;
            }
        }

        if(defined $ch and ($ch eq 'e' or $ch eq 'E')){
            $n .= $ch;
            next_chr;

            if(defined($ch) and ($ch eq '+' or $ch eq '-')){
                $n .= $ch;
                next_chr;
                if (!defined $ch or $ch =~ /\D/) {
                    decode_error("malformed number (no digits after exp sign)");
                }
                $n .= $ch;
            }
            elsif(defined($ch) and $ch =~ /\d/){
                $n .= $ch;
            }
            else {
                decode_error("malformed number (no digits after exp sign)");
            }

            while(defined(next_chr) and $ch =~ /\d/){
                $n .= $ch;
            }

        }

        $v .= $n;

        if ($v !~ /[.eE]/ and length $v > $max_intsize) {
            if ($allow_bigint) { # from Adam Sussman
                require Math::BigInt;
                return Math::BigInt->new($v);
            }
            else {
                return "$v";
            }
        }
        elsif ($allow_bigint) {
            require Math::BigFloat;
            return Math::BigFloat->new($v);
        }

        return 0+$v;
    }


    sub is_valid_utf8 {
        unless ( $utf8_len ) {
            $utf8_len = $_[0] =~ /[\x00-\x7F]/  ? 1
                      : $_[0] =~ /[\xC2-\xDF]/  ? 2
                      : $_[0] =~ /[\xE0-\xEF]/  ? 3
                      : $_[0] =~ /[\xF0-\xF4]/  ? 4
                      : 0
                      ;
        }

        return !($utf8_len = 1) unless ( $utf8_len );

        return 1 if (length ($is_valid_utf8 .= $_[0] ) < $utf8_len); # continued

        return ( $is_valid_utf8 =~ s/^(?:
             [\x00-\x7F]
            |[\xC2-\xDF][\x80-\xBF]
            |[\xE0][\xA0-\xBF][\x80-\xBF]
            |[\xE1-\xEC][\x80-\xBF][\x80-\xBF]
            |[\xED][\x80-\x9F][\x80-\xBF]
            |[\xEE-\xEF][\x80-\xBF][\x80-\xBF]
            |[\xF0][\x90-\xBF][\x80-\xBF][\x80-\xBF]
            |[\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF]
            |[\xF4][\x80-\x8F][\x80-\xBF][\x80-\xBF]
        )$//x and !($utf8_len = 0) ); # if valid, make $is_valid_utf8 empty and rest $utf8_len.

    }


    sub decode_error {
        my $error  = shift;
        my $no_rep = shift;
        my $str    = defined $text ? substr($text, $at) : '';
        my $mess   = '';
        my $type   = $] >= 5.008           ? 'U*'
                   : $] <  5.006           ? 'C*'
                   : utf8::is_utf8( $str ) ? 'U*' # 5.6
                   : 'C*'
                   ;

        for my $c ( unpack( $type, $str ) ) { # emulate pv_uni_display() ?
            $mess .=  $c == 0x07 ? '\a'
                    : $c == 0x09 ? '\t'
                    : $c == 0x0a ? '\n'
                    : $c == 0x0d ? '\r'
                    : $c == 0x0c ? '\f'
                    : $c <  0x20 ? sprintf('\x{%x}', $c)
                    : $c <  0x80 ? chr($c)
                    : sprintf('\x{%x}', $c)
                    ;
            if ( length $mess >= 20 ) {
                $mess .= '...';
                last;
            }
        }

        unless ( length $mess ) {
            $mess = '(end of string)';
        }

        Carp::croak (
            $no_rep ? "$error" : "$error, at character offset $at [\"$mess\"]"
        );
    }


    sub _json_object_hook {
        my $o    = $_[0];
        my @ks = keys %{$o};

        if ( $cb_sk_object and @ks == 1 and exists $cb_sk_object->{ $ks[0] } and ref $cb_sk_object->{ $ks[0] } ) {
            my @val = $cb_sk_object->{ $ks[0] }->( $o->{$ks[0]} );
            if (@val == 1) {
                return $val[0];
            }
        }

        my @val = $cb_object->($o) if ($cb_object);
        if (@val == 0 or @val > 1) {
            return $o;
        }
        else {
            return $val[0];
        }
    }


    sub PP_decode_box {
        {
            text    => $text,
            at      => $at,
            ch      => $ch,
            len     => $len,
            is_utf8 => $is_utf8,
            depth   => $depth,
            encoding      => $encoding,
            is_valid_utf8 => $is_valid_utf8,
        };
    }

} # PARSE


sub _decode_surrogates { # from perlunicode
    my $uni = 0x10000 + (hex($_[0]) - 0xD800) * 0x400 + (hex($_[1]) - 0xDC00);
    return pack('U*', $uni);
}


sub _decode_unicode {
    return pack("U", hex shift);
}


###############################
# Utilities
#

BEGIN {
    eval 'require Scalar::Util';
    unless($@){
        *JSON::PP::blessed = \&Scalar::Util::blessed;
    }
    else{ # This code is from Sclar::Util.
        # warn $@;
        eval 'sub UNIVERSAL::a_sub_not_likely_to_be_here { ref($_[0]) }';
        *JSON::PP::blessed = sub {
            local($@, $SIG{__DIE__}, $SIG{__WARN__});
            ref($_[0]) ? eval { $_[0]->a_sub_not_likely_to_be_here } : undef;
        };
    }
}


# shamely copied and modified from JSON::XS code.

$JSON::PP::true  = do { bless \(my $dummy = 1), "JSON::PP::Boolean" };
$JSON::PP::false = do { bless \(my $dummy = 0), "JSON::PP::Boolean" };

sub is_bool { defined $_[0] and UNIVERSAL::isa($_[0], "JSON::PP::Boolean"); }

sub true  { $JSON::PP::true  }
sub false { $JSON::PP::false }
sub null  { undef; }

###############################

package JSON::PP::Boolean;


use overload (
   "0+"     => sub { ${$_[0]} },
   "++"     => sub { $_[0] = ${$_[0]} + 1 },
   "--"     => sub { $_[0] = ${$_[0]} - 1 },
   fallback => 1,
);


###############################


1;
__END__
=pod

=head1 NAME

JSON::PP - JSON::XS compatible pure-Perl module.

=head1 SYNOPSIS

 use JSON::PP;

 # exported functions, they croak on error
 # and expect/generate UTF-8

 $utf8_encoded_json_text = encode_json $perl_hash_or_arrayref;
 $perl_hash_or_arrayref  = decode_json $utf8_encoded_json_text;

 # OO-interface

 $coder = JSON::PP->new->ascii->pretty->allow_nonref;
 $pretty_printed_unencoded = $coder->encode ($perl_scalar);
 $perl_scalar = $coder->decode ($unicode_json_text);

 # Note that JSON version 2.0 and above will automatically use
 # JSON::XS or JSON::PP, so you should be able to just:
 
 use JSON;

=head1 DESCRIPTION

This module is L<JSON::XS> compatible pure Perl module.
(Perl 5.8 or later is recommended)

JSON::XS is the fastest and most proper JSON module on CPAN.
It is written by Marc Lehmann in C, so must be compiled and
installed in the used environment.

JSON::PP is a pure-Perl module and has compatibility to JSON::XS.


=head2 FEATURES

=over

=item * correct unicode handling

This module knows how to handle Unicode (depending on Perl version).

See to L<JSON::XS/A FEW NOTES ON UNICODE AND PERL> and L<UNICODE HANDLING ON PERLS>.


=item * round-trip integrity

When you serialise a perl data structure using only datatypes supported by JSON,
the deserialised data structure is identical on the Perl level.
(e.g. the string "2.0" doesn't suddenly become "2" just because it looks like a number).


=item * strict checking of JSON correctness

There is no guessing, no generating of illegal JSON texts by default,
and only JSON is accepted as input by default (the latter is a security feature).
But when some options are set, loose chcking features are available.


=back

=head1 FUNCTIONS

=over

=item $json_text = encode_json $perl_scalar

Converts the given Perl data structure to a UTF-8 encoded, binary string.

This function call is functionally identical to:

   $json_text = JSON->new->utf8->encode($perl_scalar)


=item $perl_scalar = decode_json $json_text


The opposite of C<encode_json>: expects an UTF-8 (binary) string and tries
to parse that as an UTF-8 encoded JSON text, returning the resulting
reference.

This function call is functionally identical to:

   $perl_scalar = JSON->new->utf8->decode($json_text)


=item JSON::PP::true

Returns JSON true value which is blessed object.
It C<isa> JSON::PP::Boolean object.

=item JSON::PP::false

Returns JSON false value which is blessed object.
It C<isa> JSON::PP::Boolean object.


=item JSON::PP::null

Returns C<undef>.


=back


=head1 METHODS

=over

=item new

Rturns a new JSON::PP object that can be used to de/encode JSON
strings.

=item $json = $json->ascii([$enable])

=item $enabled = $json->get_ascii

If $enable is true (or missing), then the encode method will not generate characters outside
the code range 0..127. Any Unicode characters outside that range will be escaped using either
a single \uXXXX or a double \uHHHH\uLLLLL escape sequence, as per RFC4627.
(See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>).

In Perl 5.005, there is no character having high value (more than 255).
See to L<UNICODE HANDLING ON PERLS>.

If $enable is false, then the encode method will not escape Unicode characters unless
required by the JSON syntax or other flags. This results in a faster and more compact format.

  JSON::PP->new->ascii(1)->encode([chr 0x10401])
  => ["\ud801\udc01"]

=item latin1

=item $enabled = $json->get_latin1

If $enable is true (or missing), then the encode method will encode the resulting JSON
text as latin1 (or iso-8859-1), escaping any characters outside the code range 0..255.


If $enable is false, then the encode method will not escape Unicode characters
unless required by the JSON syntax or other flags.

  JSON::XS->new->latin1->encode (["\x{89}\x{abc}"]
  => ["\x{89}\\u0abc"]    # (perl syntax, U+abc escaped, U+89 not)

See to L<UNICODE HANDLING ON PERLS>.


=item $json = $json->utf8([$enable])

=item $enabled = $json->get_utf8

If $enable is true (or missing), then the encode method will encode the JSON result
into UTF-8, as required by many protocols, while the decode method expects to be handled
an UTF-8-encoded string. Please note that UTF-8-encoded strings do not contain any
characters outside the range 0..255, they are thus useful for bytewise/binary I/O.

(In Perl 5.005, any character outside the range 0..255 does not exist.
See to L<UNICODE HANDLING ON PERLS>.)

In future versions, enabling this option might enable autodetection of the UTF-16 and UTF-32
encoding families, as described in RFC4627.

If $enable is false, then the encode method will return the JSON string as a (non-encoded)
Unicode string, while decode expects thus a Unicode string. Any decoding or encoding
(e.g. to UTF-8 or UTF-16) needs to be done yourself, e.g. using the Encode module.

Example, output UTF-16BE-encoded JSON:

  use Encode;
  $jsontext = encode "UTF-16BE", JSON::XS->new->encode ($object);

Example, decode UTF-32LE-encoded JSON:

  use Encode;
  $object = JSON::XS->new->decode (decode "UTF-32LE", $jsontext);


=item $json = $json->pretty([$enable])

This enables (or disables) all of the C<indent>, C<space_before> and
C<space_after> flags in one call to generate the most readable
(or most compact) form possible.

Equivalent to:

   $json->indent->space_before->space_after

Example, pretty-print some simple structure:

   my $json = JSON->new->pretty(1)->encode ({a => [1,2]})
   =>
   {
      "a" : [
         1,
         2
      ]
   }

The indent space length is three.


=item $json = $json->indent([$enable])

=item $enabled = $json->get_indent

If C<$enable> is true (or missing), then the C<encode> method will use a multiline
format as output, putting every array member or object/hash key-value pair
into its own line, identing them properly.

If C<$enable> is false, no newlines or indenting will be produced, and the
resulting JSON text is guarenteed not to contain any C<newlines>.

This setting has no effect when decoding JSON texts.

The default indent space lenght is three.
You can use C<indent_length> to change the length.


=item $json = $json->space_before([$enable])

=item $enabled = $json->get_space_before

If C<$enable> is true (or missing), then the C<encode> method will add an extra
optional space before the C<:> separating keys from values in JSON objects.

If C<$enable> is false, then the C<encode> method will not add any extra
space at those places.

This setting has no effect when decoding JSON texts.

Example, space_before enabled, space_after and indent disabled:

   {"key" :"value"}


=item $json = $json->space_after([$enable])

=item $enabled = $json->get_space_after

If C<$enable> is true (or missing), then the C<encode> method will add an extra
optional space after the C<:> separating keys from values in JSON objects
and extra whitespace after the C<,> separating key-value pairs and array
members.

If C<$enable> is false, then the C<encode> method will not add any extra
space at those places.

This setting has no effect when decoding JSON texts.

Example, space_before and indent disabled, space_after enabled:

   {"key": "value"}


=item $json = $json->relaxed([$enable])

=item $enabled = $json->get_relaxed

If C<$enable> is true (or missing), then C<decode> will accept some
extensions to normal JSON syntax (see below). C<encode> will not be
affected in anyway. I<Be aware that this option makes you accept invalid
JSON texts as if they were valid!>. I suggest only to use this option to
parse application-specific files written by humans (configuration files,
resource files etc.)

If C<$enable> is false (the default), then C<decode> will only accept
valid JSON texts.

Currently accepted extensions are:

=over 4

=item * list items can have an end-comma

JSON I<separates> array elements and key-value pairs with commas. This
can be annoying if you write JSON texts manually and want to be able to
quickly append elements, so this extension accepts comma at the end of
such items not just between them:

   [
      1,
      2, <- this comma not normally allowed
   ]
   {
      "k1": "v1",
      "k2": "v2", <- this comma not normally allowed
   }

=item * shell-style '#'-comments

Whenever JSON allows whitespace, shell-style comments are additionally
allowed. They are terminated by the first carriage-return or line-feed
character, after which more white-space and comments are allowed.

  [
     1, # this comment not allowed in JSON
        # neither this one...
  ]

=back


=item $json = $json->canonical([$enable])

=item $enabled = $json->get_canonical

If C<$enable> is true (or missing), then the C<encode> method will output JSON objects
by sorting their keys. This is adding a comparatively high overhead.

If C<$enable> is false, then the C<encode> method will output key-value
pairs in the order Perl stores them (which will likely change between runs
of the same script).

This option is useful if you want the same data structure to be encoded as
the same JSON text (given the same overall settings). If it is disabled,
the same hash might be encoded differently even if contains the same data,
as key-value pairs have no inherent ordering in Perl.

This setting has no effect when decoding JSON texts.

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>

If you want your own sorting routine, you can give a code referece
or a subroutine name to C<sort_by>. See to C<JSON::PP OWN METHODS>.


=item $json = $json->allow_nonref([$enable])

=item $enabled = $json->get_allow_nonref

If C<$enable> is true (or missing), then the C<encode> method can convert a
non-reference into its corresponding string, number or null JSON value,
which is an extension to RFC4627. Likewise, C<decode> will accept those JSON
values instead of croaking.

If C<$enable> is false, then the C<encode> method will croak if it isn't
passed an arrayref or hashref, as JSON texts must either be an object
or array. Likewise, C<decode> will croak if given something that is not a
JSON object or array.

   JSON->new->allow_nonref->encode ("Hello, World!")
   => "Hello, World!"

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>.


=item $json = $json->allow_blessed([$enable])

=item $enabled = $json->get_allow_blessed

If C<$enable> is true (or missing), then the C<encode> method will not
barf when it encounters a blessed reference. Instead, the value of the
B<convert_blessed> option will decide whether C<null> (C<convert_blessed>
disabled or no C<TO_JSON> method found) or a representation of the
object (C<convert_blessed> enabled and C<TO_JSON> method found) is being
encoded. Has no effect on C<decode>.

If C<$enable> is false (the default), then C<encode> will throw an
exception when it encounters a blessed object.

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>


=item $json = $json->convert_blessed([$enable])

=item $enabled = $json->get_convert_blessed

If C<$enable> is true (or missing), then C<encode>, upon encountering a
blessed object, will check for the availability of the C<TO_JSON> method
on the object's class. If found, it will be called in scalar context
and the resulting scalar will be encoded instead of the object. If no
C<TO_JSON> method is found, the value of C<allow_blessed> will decide what
to do.

The C<TO_JSON> method may safely call die if it wants. If C<TO_JSON>
returns other blessed objects, those will be handled in the same
way. C<TO_JSON> must take care of not causing an endless recursion cycle
(== crash) in this case. The name of C<TO_JSON> was chosen because other
methods called by the Perl core (== not by the user of the object) are
usually in upper case letters and to avoid collisions with the C<to_json>
function or method.

This setting does not yet influence C<decode> in any way.

If C<$enable> is false, then the C<allow_blessed> setting will decide what
to do when a blessed object is found.

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>


=item $json = $json->filter_json_object([$coderef])

When C<$coderef> is specified, it will be called from C<decode> each
time it decodes a JSON object. The only argument passed to the coderef
is a reference to the newly-created hash. If the code references returns
a single scalar (which need not be a reference), this value
(i.e. a copy of that scalar to avoid aliasing) is inserted into the
deserialised data structure. If it returns an empty list
(NOTE: I<not> C<undef>, which is a valid scalar), the original deserialised
hash will be inserted. This setting can slow down decoding considerably.

When C<$coderef> is omitted or undefined, any existing callback will
be removed and C<decode> will not change the deserialised hash in any
way.

Example, convert all JSON objects into the integer 5:

   my $js = JSON->new->filter_json_object (sub { 5 });
   # returns [5]
   $js->decode ('[{}]'); # the given subroutine takes a hash reference.
   # throw an exception because allow_nonref is not enabled
   # so a lone 5 is not allowed.
   $js->decode ('{"a":1, "b":2}');

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>

=item $json = $json->filter_json_single_key_object($key [=> $coderef])


Works remotely similar to C<filter_json_object>, but is only called for
JSON objects having a single key named C<$key>.

This C<$coderef> is called before the one specified via
C<filter_json_object>, if any. It gets passed the single value in the JSON
object. If it returns a single value, it will be inserted into the data
structure. If it returns nothing (not even C<undef> but the empty list),
the callback from C<filter_json_object> will be called next, as if no
single-key callback were specified.

If C<$coderef> is omitted or undefined, the corresponding callback will be
disabled. There can only ever be one callback for a given key.

As this callback gets called less often then the C<filter_json_object>
one, decoding speed will not usually suffer as much. Therefore, single-key
objects make excellent targets to serialise Perl objects into, especially
as single-key JSON objects are as close to the type-tagged value concept
as JSON gets (it's basically an ID/VALUE tuple). Of course, JSON does not
support this in any way, so you need to make sure your data never looks
like a serialised Perl hash.

Typical names for the single object key are C<__class_whatever__>, or
C<$__dollars_are_rarely_used__$> or C<}ugly_brace_placement>, or even
things like C<__class_md5sum(classname)__>, to reduce the risk of clashing
with real hashes.

Example, decode JSON objects of the form C<< { "__widget__" => <id> } >>
into the corresponding C<< $WIDGET{<id>} >> object:

   # return whatever is in $WIDGET{5}:
   JSON
      ->new
      ->filter_json_single_key_object (__widget__ => sub {
            $WIDGET{ $_[0] }
         })
      ->decode ('{"__widget__": 5')

   # this can be used with a TO_JSON method in some "widget" class
   # for serialisation to json:
   sub WidgetBase::TO_JSON {
      my ($self) = @_;

      unless ($self->{id}) {
         $self->{id} = ..get..some..id..;
         $WIDGET{$self->{id}} = $self;
      }

      { __widget__ => $self->{id} }
   }

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>


=item $json = $json->shrink([$enable])

=item $enabled = $json->get_shrink

In JSON::XS, this flag resizes strings generated by either
C<encode> or C<decode> to their minimum size possible.
It will also try to downgrade any strings to octet-form if possible.

In JSON::PP, it is noop about resizing strings but tries
C<utf8::downgrade> to the returned string by C<encode>.
See to L<utf8>.

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>


=item $json = $json->max_depth([$maximum_nesting_depth])

=item $max_depth = $json->get_max_depth

Sets the maximum nesting level (default C<512>) accepted while encoding
or decoding. If the JSON text or Perl data structure has an equal or
higher nesting level then this limit, then the encoder and decoder will
stop and croak at that point.

Nesting level is defined by number of hash- or arrayrefs that the encoder
needs to traverse to reach a given point or the number of C<{> or C<[>
characters without their matching closing parenthesis crossed to reach a
given character in a string.

The argument to C<max_depth> will be rounded up to the next highest power
of two. If no argument is given, the highest possible setting will be
used, which is rarely useful.

This rounding up feature is for JSON::XS internal C structure.
To the compatibility, JSON::PP has the same feature.

See L<JSON::XS/SSECURITY CONSIDERATIONS> for more info on why this is useful.

When a large value (100 or more) was set and it de/encodes a deep nested object/text,
it may raise a warning 'Deep recursion on subroutin' at the perl runtime phase.


=item $json = $json->max_size([$maximum_string_size])

=item $max_size = $json->get_max_size

Set the maximum length a JSON text may have (in bytes) where decoding is
being attempted. The default is C<0>, meaning no limit. When C<decode>
is called on a string longer then this number of characters it will not
attempt to decode the string but throw an exception. This setting has no
effect on C<encode> (yet).

The argument to C<max_size> will be rounded up to the next B<highest>
power of two (so may be more than requested). If no argument is given, the
limit check will be deactivated (same as when C<0> is specified).

This rounding up feature is for JSON::XS internal C structure.
To the compatibility, JSON::PP has the same feature.

See L<JSON::XS/SSECURITY CONSIDERATIONS> for more info on why this is useful.


=item $json_text = $json->encode($perl_scalar)

Converts the given Perl data structure (a simple scalar or a reference
to a hash or array) to its JSON representation. Simple scalars will be
converted into JSON string or number sequences, while references to arrays
become JSON arrays and references to hashes become JSON objects. Undefined
Perl values (e.g. C<undef>) become JSON C<null> values. Neither C<true>
nor C<false> values will be generated.

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>


=item $perl_scalar = $json->decode($json_text)

The opposite of C<encode>: expects a JSON text and tries to parse it,
returning the resulting simple scalar or reference. Croaks on error.

JSON numbers and strings become simple Perl scalars. JSON arrays become
Perl arrayrefs and JSON objects become Perl hashrefs. C<true> becomes
C<1>, C<false> becomes C<0> and C<null> becomes C<undef>.

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>


=item ($perl_scalar, $characters) = $json->decode_prefix($json_text)

This works like the C<decode> method, but instead of raising an exception
when there is trailing garbage after the first JSON object, it will
silently stop parsing there and return the number of characters consumed
so far.

   JSON->new->decode_prefix ("[1] the tail")
   => ([], 3)

See to L<JSON::XS/OBJECT-ORIENTED INTERFACE>

=back


=head1 JSON::PP OWN METHODS

=over

=item $json = $json->allow_singlequote([$enable])

If C<$enable> is true (or missing), then C<decode> will accept
JSON strings quoted by single quotations that are invalid JSON
format.

    $json->allow_singlequote->decode({"foo":'bar'});
    $json->allow_singlequote->decode({'foo':"bar"});
    $json->allow_singlequote->decode({'foo':'bar'});

As same as the C<relaxed> option, this option may be used to parse
application-specific files written by humans.


=item $json = $json->allow_barekey([$enable])

If C<$enable> is true (or missing), then C<decode> will accept
bare keys of JSON object that are invalid JSON format.

As same as the C<relaxed> option, this option may be used to parse
application-specific files written by humans.

    $json->allow_barekey->decode({foo:"bar"});

=item $json = $json->allow_bignum([$enable])

If C<$enable> is true (or missing), then C<decode> will convert
the big integer Perl cannot handle as integer into a L<Math::BigInt>
object and convert a floating number (any) into a L<Math::BigFloat>.

On the contary, C<encode> converts C<Math::BigInt> objects and C<Math::BigFloat>
objects into JSON numbers with C<allow_blessed> enable.

   $json->allow_nonref->allow_blessed->allow_bignum;
   $bigfloat = $json->decode('2.000000000000000000000000001');
   print $json->encode($bigfloat);
   # => 2.000000000000000000000000001

See to L<JSON::XS/MAPPING> aboout the normal conversion of JSON number.


=item $json = $json->loose([$enable])

The unescaped [\x00-\x1f\x22\x2f\x5c] strings are invalid in JSON strings
and the module doesn't allow to C<decode> to these (except for \x2f).
If C<$enable> is true (or missing), then C<decode>  will accept these
unescaped strings.

    $json->loose->decode(qq|["abc
                                   def"]|);

See L<JSON::XS/SSECURITY CONSIDERATIONS>.


=item $json = $json->escape_slash([$enable])

According to JSON Grammar, I<slash> (U+002F) is escaped. But default
JSON::PP (as same as JSON::XS) encodes strings without escaping slash.

If C<$enable> is true (or missing), then C<encode> will escape slashes.

=item $json = $json->as_nonblessed

(EXPERIMENTAL)
If C<$enable> is true (or missing), then C<encode> will convert
a blessed hash reference or a blessed array reference (contains
other blessed references) into JSON members and arrays.

This feature is effective only when C<allow_blessed> is enable.

=item $json = $json->indent_length([$length])

JSON::XS indent space length is 3 and cannot be changed.
JSON::PP set the indent space length with the given $length.
The default is 3. The acceptable range is 0 to 15.


=item $json = $json->sort_by($function_name)

=item $json = $json->sort_by($subroutine_ref)

If $function_name or $subroutine_ref are set, its sort routine are used
in encoding JSON objects.

   $js = $pc->sort_by(sub { $JSON::PP::a cmp $JSON::PP::b })->encode($obj);
   # is($js, q|{"a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8,"i":9}|);

   $js = $pc->sort_by('own_sort')->encode($obj);
   # is($js, q|{"a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8,"i":9}|);

   sub JSON::PP::own_sort { $JSON::PP::a cmp $JSON::PP::b }

As the sorting routine runs in the JSON::PP scope, the given
subroutine name and the special variables C<$a>, C<$b> will begin
'JSON::PP::'.

If $integer is set, then the effect is same as C<canonical> on.


=back

=head1 INTERNAL

For developers.

=over

=item PP_encode_box

Returns

        {
            depth        => $depth,
            indent_count => $indent_count,
        }


=item PP_decode_box

Returns

        {
            text    => $text,
            at      => $at,
            ch      => $ch,
            len     => $len,
            is_utf8 => $is_utf8,
            depth   => $depth,
            encoding      => $encoding,
            is_valid_utf8 => $is_valid_utf8,
        };

=back

=head1 MAPPING

See to L<JSON::XS/MAPPING>.


=head1 UNICODE HANDLING ON PERLS

If you do not know about Unicode on Perl well,
please check L<JSON::XS/A FEW NOTES ON UNICODE AND PERL>.

=head2 Perl 5.8 and later

Perl can handle Unicode and the JSON::PP de/encode methods also work properly.

    $json->allow_nonref->encode(chr hex 3042);
    $json->allow_nonref->encode(chr hex 12345);

Reuturns C<"\u3042"> and C<"\ud808\udf45"> respectively.

    $json->allow_nonref->decode('"\u3042"');
    $json->allow_nonref->decode('"\ud808\udf45"');

Returns UTF-8 encoded strings with UTF8 flag, regarded as C<U+3042> and C<U+12345>.

Note that the versions from Perl 5.8.0 to 5.8.2, Perl built-in C<join> was broken,
so JSON::PP wraps the C<join> with a subroutine. Thus JSON::PP works slow in the versions.


=head2 Perl 5.6

Perl can handle Unicode and the JSON::PP de/encode methods also work.

=head2 Perl 5.005

Perl 5.005 is a byte sementics world -- all strings are sequences of bytes.
That means the unicode handling is not available.

In encoding,

    $json->allow_nonref->encode(chr hex 3042);  # hex 3042 is 12354.
    $json->allow_nonref->encode(chr hex 12345); # hex 12345 is 74565.

Returns C<B> and C<E>, as C<chr> takes a value more than 255, it treats
as C<$value % 256>, so the above codes are equivalent to :

    $json->allow_nonref->encode(chr 66);
    $json->allow_nonref->encode(chr 69);

In decoding,

    $json->decode('"\u00e3\u0081\u0082"');

The returned is a byte sequence C<0xE3 0x81 0x82> for UTF-8 encoded
japanese character (C<HIRAGANA LETTER A>).
And if it is represented in Unicode code point, C<U+3042>.

Next, 

    $json->decode('"\u3042"');

We ordinary expect the returned value is a Unicode character C<U+3042>.
But here is 5.005 world. This is C<0xE3 0x81 0x82>.

    $json->decode('"\ud808\udf45"');

This is not a character C<U+12345> but bytes - C<0xf0 0x92 0x8d 0x85>.


=head1 TODO

=over

=back


=head1 SEE ALSO

Most of the document are copied and modified from JSON::XS doc.

L<JSON::XS>

RFC4627 (L<http://www.ietf.org/rfc/rfc4627.txt>)

=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
