#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class Counter;
has $count;

method new : common {
  my $self = $class->SUPER::new(@_);
  
  $self->{count} //= 0;
  
  return $self;
}

method count :lvalue { $self->{count} }
method inc { $self->{count}++ }

package main;

{
   my $counter = Counter->new;
   $counter->inc;
   is( $counter->count, 1, 'Count is now 1' );
}

done_testing;
