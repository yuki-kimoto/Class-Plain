#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Scalar::Util qw( reftype );

use Object::Pad;

class Point {
   has $x : param;
   has $y : param;

   method new : common {
     my $self = bless [@_], $class;
     
     my @field_names = qw(x y);
     my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
     $self->[$field_ids{x}] = 0 unless defined $field_ids{x};
     $self->[$field_ids{y}] = 0 unless defined $field_ids{y};
     
     return $self;
   }

   method where { sprintf "(%d,%d)", $x, $y }
}

{
   my $p = Point->new(10,20);
   is( $p->where, "(10,20)", '$p->where' );
}

my @build;

{
   my $newarg_destroyed;
   my $buildargs_result_destroyed;
   package DestroyWatch {
      sub new { bless [ $_[1] ], $_[0] }
      sub DESTROY { ${ $_[0][0] }++ }
   }

   class RefcountTest {
   }

   RefcountTest->new( DestroyWatch->new( \$newarg_destroyed ) );

   is( $newarg_destroyed, 1, 'argument to ->new destroyed' );
}

done_testing;
