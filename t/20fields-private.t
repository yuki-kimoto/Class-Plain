#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

{
  class Base::Class {
     field $data;
     method data { $data }

     method new : common {
       my $self = bless [], $class;
       
       $self->[0] = "base data";
       
       return $self;
     }
  }

  class Derived::Class :isa(Base::Class) {
     field $data;
     method data { $data }

     method new : common {
       my $self = $class->SUPER::new(@_);
       
       $self->[1] = "derived data";
       
       return $self;
     }
  }

  {
     my $c = Derived::Class->new;
     is( $c->data, "derived data",
        'subclass wins methods' );
     is( $c->Base::Class::data, "base data",
        'base class still accessible' );
  }
}

done_testing;
