#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class AClass {
   field $data :param;

   method new : common {
     my $self = {@_};
     
     return bless $self, ref $class || $class;
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
