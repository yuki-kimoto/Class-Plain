#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;
use Test::Refcount;

use Object::Pad ':experimental(init_expr)';

use constant HAVE_DATA_DUMP => defined eval { require Data::Dump; };

class Counter {
   has $count;
   
   method new : common {
     my $self = $class->SUPER::new(@_);
     
     $self->{count} //= 0;
     
     return $self;
   }

   method inc { $self->{count}++ }

   method describe { "Count is now $self->{count}" }
}

{
   my $counter = Counter->new;
   $counter->inc;
   $counter->inc;
   $counter->inc;

   is( $counter->describe, "Count is now 3",
      '$counter->describe after $counter->inc x 3' );

   # BEGIN-time initialised fields get private storage
   my $counter2 = Counter->new;
   is( $counter2->describe, "Count is now 0",
      '$counter2 has its own $count' );
}

{
   use Data::Dumper;

   class AllTheTypes {
      has $scalar;

     method new : common {
       my $self = $class->SUPER::new(@_);
       
       $self->{scalar} //= 123;
       
       return $self;
     }

      method test {
         Test::More::is( $self->{scalar}, 123, '$scalar field' );
      }
   }

   my $instance = AllTheTypes->new;

   $instance->test;
}

done_testing;
