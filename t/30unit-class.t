#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class Counter;
has $count;

 method new : common {
   my $self = bless [], $class;
   
   my @field_names = qw(count);
   my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
   $self->[$field_ids{count}] = 0;
   
   return $self;
 }

method count :lvalue { $count }
method inc { $count++ }

package main;

{
   my $counter = Counter->new;
   $counter->inc;
   is( $counter->count, 1, 'Count is now 1' );
}

done_testing;
