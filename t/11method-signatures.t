#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

BEGIN {
   $] >= 5.026000 or plan skip_all => "No parse_subsignature()";
}

use Object::Pad;

class Greeter {
   field $_who;

   BUILD ( %args ) {
      $_who = $args{who};
   }

   method greet ( $message = "Hello, $_who" ) {
      return $message;
   }
}

{
   my $g = Greeter->new(who => "unit test");

   is( $g->greet, "Hello, unit test",
      'subroutine signature default exprs can see instance fields'
   );
}

done_testing;
