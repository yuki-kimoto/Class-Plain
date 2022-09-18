#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class Point {
   has $x :param;
   has $y :param;
   
   ADJUST {
     $y = 0 unless length $y;
   }

   method pos { return ( $x, $y ); }
}

{
   my $point = Point->new( x => 10 );
   is_deeply( [ $point->pos ], [ 10, 0 ],
      'Point with default y' );
}

{
   my $point = Point->new( x => 30, y => 40 );
   is_deeply( [ $point->pos ], [ 30, 40 ],
      'Point fully specified' );
}

class Point3D :isa(Point) {
   has $z :param;
   ADJUST {
     $z = 0 unless length $z;
   }

   method pos { return ( $self->next::method, $z ) }
}

{
   my $point = Point3D->new( x => 50, y => 60, z => 70 );
   is_deeply( [ $point->pos ], [ 50, 60, 70 ],
      'Point3D inherits params' );
}

done_testing;
