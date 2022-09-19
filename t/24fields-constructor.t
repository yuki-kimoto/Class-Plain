#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class Point {
   has $x;
   has $y;

   method new : common {
     my $self = bless [$_[1], $_[3]], $class;
     
     my @field_names = qw(x y);
     my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
     $self->[$field_ids{x}] = 0 unless defined $self->[$field_ids{x}];
     $self->[$field_ids{y}] = 0 unless defined $self->[$field_ids{y}];
     
     return $self;
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
   has $z;
   
   method new : common {
     my $self = bless [$_[1], $_[3], $_[5]], $class;
     
     my @field_names = qw(x y z);
     my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
     $self->[$field_ids{z}] = 0 unless defined $self->[$field_ids{z}];
     
     return $self;
   }

   method pos { return ( $self->next::method, $z ) }
}

{
   my $point = Point3D->new( x => 50, y => 60, z => 70 );
   is_deeply( [ $point->pos ], [ 50, 60, 70 ],
      'Point3D inherits params' );
}

done_testing;
