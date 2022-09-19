#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

class Point {
   has x;
   has y;

   method new : common {
     my $self = $class->SUPER::new(@_);
     
     $self->{x} //= 0;
     $self->{y} //= 0;
     
     return $self;
   }
   
   method pos { return ( $self->{x}, $self->{y} ); }
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
   has z;
   
   method new : common {
     my $self = $class->SUPER::new(@_);
     
     $self->{z} //= 0;
     
     return $self;
   }

   method pos { return ( $self->SUPER::pos, $self->{z} ) }
}

{
   my $point = Point3D->new( x => 50, y => 60, z => 70 );
   is_deeply( [ $point->pos ], [ 50, 60, 70 ],
      'Point3D inherits params' );
}

done_testing;
