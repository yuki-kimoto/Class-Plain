#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

class BaseClass {
   field data;

   method new : common {
     my $self = $class->SUPER::new(@_);
     
     $self->{data} //= 123;
     
     return $self;
   }
}

package ExtendedClass {
   use base qw( BaseClass );

   sub moremethod { return 456 }
}

my $obj = ExtendedClass->new;
isa_ok( $obj, "ExtendedClass", '$obj' );

is( $obj->moremethod, 456, '$obj field methods from ExtendedClass' );

done_testing;