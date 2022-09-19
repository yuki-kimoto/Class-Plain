#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Scalar::Util qw( reftype );

use Object::Pad;

class Point {
   has $x : param;
   has $y : param;
   ADJUST {
     $x = 0 unless length $x;
     $y = 0 unless length $y;
   }
   
   method new_xy : common {
     return $class->new(x => $_[0], y => $_[1]);
   }

   method where { sprintf "(%d,%d)", $x, $y }
}

{
   my $p = Point->new_xy(10,20);
   is( $p->where, "(10,20)", '$p->where' );
}

my @build;

{
   my @called;
   my $paramsref;

   class WithADJUST {
      ADJUST {
         push @called, "ADJUST";
      }

      ADJUST {
         my ( $href ) = @_;
         push @called, "ADJUST";
         $paramsref = $href;
      }

      ADJUST {
         push @called, "ADJUST";
      }
   }

   WithADJUST->new( key => "val" );
   is_deeply( \@called, [qw( ADJUST ADJUST ADJUST )], 'ADJUST and ADJUST invoked together' );
   is_deeply( $paramsref, { key => "val" }, 'ADJUST received HASHref' );
}

{
   my $newarg_destroyed;
   my $buildargs_result_destroyed;
   package DestroyWatch {
      sub new { bless [ $_[1] ], $_[0] }
      sub DESTROY { ${ $_[0][0] }++ }
   }

   class RefcountTest {
   }

   RefcountTest->new( DestroyWatch->new( \$newarg_destroyed ) );

   is( $newarg_destroyed, 1, 'argument to ->new destroyed' );
}

# Create a base class with HASH representation
{
   class NativelyHash :repr(HASH) {
      has $field;
      ADJUST {
        $field = "value";
      }
      method field { $field }
   }

   my $o = NativelyHash->new;
   is( reftype $o, "HASH", 'NativelyHash is natively a HASH reference' );
   is( $o->field, "value", 'native HASH objects still support fields' );
}

done_testing;
