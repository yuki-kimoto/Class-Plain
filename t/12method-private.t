#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class AClass {
   field $data;

   method new : common {
     my $self = $class->SUPER::new(@_);
     
     return $self;
   }

   my $priv = method {
      "data<$self->{data}>";
   };

   method m { return $self->$priv }
}

{
   my $obj = AClass->new( data => "value" );
   is( $obj->m, "data<value>", 'method can invoke captured method ref' );
}

done_testing;
