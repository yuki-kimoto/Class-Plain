#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Scalar::Util qw( reftype );

use Object::Pad;

class Point {
   has $x;
   has $y;
   ADJUST {
     $x = 0 unless length $x;
     $y = 0 unless length $y;
   }

   BUILD {
      ( $x, $y ) = @_;
   }

   method where { sprintf "(%d,%d)", $x, $y }
}

{
   my $p = Point->new( 10, 20 );
   is( $p->where, "(10,20)", '$p->where' );
}

my @build;

{
   my @called;

   class WithAdjust {
      BUILD {
         push @called, "BUILD";
      }

      ADJUST {
         push @called, "ADJUST";
      }
   }

   WithAdjust->new;
   is_deeply( \@called, [qw( BUILD ADJUST )], 'ADJUST invoked after BUILD' );
}

{
   my @called;
   my $paramsref;

   class WithAdjustParams {
      ADJUST {
         push @called, "ADJUST";
      }

      ADJUSTPARAMS {
         my ( $href ) = @_;
         push @called, "ADJUSTPARAMS";
         $paramsref = $href;
      }

      ADJUST {
         push @called, "ADJUST";
      }
   }

   WithAdjustParams->new( key => "val" );
   is_deeply( \@called, [qw( ADJUST ADJUSTPARAMS ADJUST )], 'ADJUST and ADJUSTPARAMS invoked together' );
   is_deeply( $paramsref, { key => "val" }, 'ADJUSTPARAMS received HASHref' );
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

# Subclasses without BUILD shouldn't double-invoke superclass
{
   my $BUILD_invoked;
   class One {
      BUILD { $BUILD_invoked++ }
   }
   class Two :isa(One) {}

   Two->new;
   is( $BUILD_invoked, 1, 'One::BUILD invoked only once for Two->new' );
}

done_testing;
