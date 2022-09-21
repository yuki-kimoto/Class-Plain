#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

class BaseClassic {
   field data;

   method new : common {
     my $self = $class->SUPER::new(@_);
     
     $self->{data} //= 123;
     
     return $self;
   }
}

package ExtendedClassic {
   use base qw( BaseClassic );

   sub moremethod { return 456 }
}

my $obj = ExtendedClassic->new;
isa_ok( $obj, "ExtendedClassic", '$obj' );

is( $obj->moremethod, 456, '$obj field methods from ExtendedClassic' );

done_testing;
