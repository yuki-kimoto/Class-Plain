#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad ':experimental( mop )';
use Object::Pad::MetaFunctions qw(
   metaclass
   deconstruct_object
   ref_field
   get_field
);

class Point {
   has $x :param = 0;
   has $y :param = 0;
}

is( metaclass( Point->new ), Object::Pad::MOP::Class->for_class( "Point" ),
   'metaclass() returns Point metaclass' );

class AllFieldTypes {
   has $s = "scalar";
}

is_deeply( [ deconstruct_object( AllFieldTypes->new ) ],
   [ 'AllFieldTypes',
     'AllFieldTypes.$s' => "scalar",
   ],
  'deconstruct_object on AllFieldTypes' );

class AClass {
   has $a = "a";
}
role BRole {
   has $b = "b";
}
class CClass :isa(AClass) :does(BRole) {
   has $c = "c";
}

is_deeply( [ deconstruct_object( CClass->new ) ],
   [ 'CClass',
     'CClass.$c' => "c",
     'BRole.$b'  => "b",
     'AClass.$a' => "a", ],
   'deconstruct_object on CClass' );

# ref_field
{
   my $obj = AllFieldTypes->new;

   is_deeply( ref_field( 'AllFieldTypes.$s', $obj ), \"scalar",
      'ref_field on scalar field' );

   is_deeply( ref_field( '$s', $obj ), \"scalar",
      'ref_field short name' );

   is_deeply( ref_field( 'BRole.$b', CClass->new ), \"b",
      'ref_field can search roles' );
}

# get_field
{
   my $obj = AllFieldTypes->new;

   is( get_field( '$s', $obj ), "scalar",
      'get_field on scalar field' );

}

done_testing;
