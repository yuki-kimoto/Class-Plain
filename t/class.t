#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

use Scalar::Util qw( reftype );

use Class::Plain;

{
  class MyClassField {
    field x;
    field y;
    method where { sprintf "(%d,%d)", $self->{x}, $self->{y} }
  }

  {
    my $p = MyClassField->new(x => 10, y => 20);
    is( $p->where, "(10,20)", '$p->where' );
  }

  {
    my $p = MyClassField->new({x => 10, y => 20});
    is( $p->where, "(10,20)", '$p->where' );
  }
}

{
  class PointArgs {
    field x;
    field y;

    method new : common {
      my $self = $class->SUPER::new(x => $_[0], y => $_[1]);
      
      $self->{x} //= 0;
      $self->{y} //= 0;
      
      return $self;
    }

    method where { sprintf "(%d,%d)", $self->{x}, $self->{y} }
  }

  {
     my $p = PointArgs->new(10,20);
     is( $p->where, "(10,20)", '$p->where' );
  }
}

# Package Variable
{
  class MyClassPackageVariable {
    our $FOO;
    my $BAR;
    
    INIT {
      $FOO = 1;
      $BAR = 2;
    }
    
    method FOO : common { $FOO }
    method BAR : common { $BAR }
  }

  {
    is(MyClassPackageVariable->FOO, 1);
    is(MyClassPackageVariable->BAR, 2);
  }
}

{
  use ModuleClass;
  
  my $object = ModuleClass->new(x => 1);
  is($object->x, 1);
  $object->set_y(2);
  is($object->{y}, 2);
  $object->z(3);
  is($object->z, 3);
}

done_testing;
