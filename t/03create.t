#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Scalar::Util qw( reftype );

use Class::Plain;

class Point {
   field x;
   field y;

   method new : common {
     my $self = $class->SUPER::new(x => $_[0], y => $_[1]);
     
     $self->{x} //= 0;
     $self->{y} //= 0;
     
     return $self;
   }

   method where { sprintf "(%d,%d)", $self->{x}, $self->{y} }
}

{
   my $p = Point->new(10,20);
   is( $p->where, "(10,20)", '$p->where' );
}

my @build;

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

done_testing;
