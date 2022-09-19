#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;
use Test::Refcount;

use Object::Pad;

class Point {
   has $x : param;
   has $y : param;
   
   method where { sprintf "(%d,%d)", @$self }
}

{
   my $p = Point->new(x => 10, y => 20 );
   is_oneref( $p, '$p has refcount 1 initially' );

   is( $p->where, "(10,20)", '$p->where' );
   is_oneref( $p, '$p has refcount 1 after method' );
}

# anon methods
{
   class Point3 {
     has $x : param;
     has $y : param;
     has $z : param;
     
      our $clearer = method {
         @$self = ( 0 ) x 3;
      };
   }

   my $p = Point3->new(x => 1, y => 2, z => 3 );
   $p->$Point3::clearer();

   is_deeply( [ @$p ], [ 0, 0, 0 ],
      'anon method' );
}

# nested anon method (RT132321)
SKIP: {
   skip "This causes SEGV on perl 5.16 (RT132321)", 1 if $] lt "5.018";
   class RT132321 {
      has $_genvalue;

      ADJUST {
         $_genvalue = method { 123 };
      }

      method value { $self->$_genvalue() }
   }

   my $obj = RT132321->new;
   is( $obj->value, 123, '$obj->value from ADJUST-generated anon method' );
}

# method warns about redeclared $self (RT132428)
{
   class RT132428 {
      BEGIN {
         my $warnings = "";
         local $SIG{__WARN__} = sub { $warnings .= join "", @_; };

         ::ok( defined eval <<'EOPERL',
            method test {
               my $self = shift;
            }
            1;
EOPERL
            'method compiles OK' );

         ::like( $warnings,
            qr/^"my" variable \$self masks earlier declaration in same scope at \(eval \d+\) line 2\./,
            'warning from redeclared $self comes from correct line' );
      }
   }
}

done_testing;
