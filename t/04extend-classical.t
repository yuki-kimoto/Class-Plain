#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class BaseClass {
   has $data;

   method new : common {
     my $self = bless [], $class;
     
     my @field_names = qw(data);
     my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
     $self->[$field_ids{data}] = 123;
     
     return $self;
   }
}

package ExtendedClass {
   use base qw( BaseClass );

   sub moremethod { return 456 }
}

my $obj = ExtendedClass->new;
isa_ok( $obj, "ExtendedClass", '$obj' );

is( $obj->moremethod, 456, '$obj has methods from ExtendedClass' );

done_testing;
