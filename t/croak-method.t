#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

class Point {
   field x;
   method clear { $self->{x} = 0 }
}

{
   ok( !eval { Point->clear },
      'method on non-instance fails' );
   like( $@, qr/^Cannot invoke method on a non-instance /,
      'message from method on non-instance' );
}

done_testing;
