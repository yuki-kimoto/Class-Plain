#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

use Class::Plain;

{
  class MyClassForMyRoleDeclaration : does(RoleMinimal) does(RoleMinimal2) {
    method foo {
      return $self->role_foo;
    }
    
    method role_bar { "cur_bar" }

    method role_bar_role { $self->RoleMinimal::role_bar }
    
    method required_method1 {
      return 2;
    }
  }
  
  my $object = MyClassForMyRoleDeclaration->new;
  is($object->foo, 1);
  is($object->role_bar, "cur_bar");
  is($object->role_bar_role, "role_bar");
  is($object->role_minimal2_foo_method, "role_minimal2_foo_method");
  $object->x(5);
  is($object->x, 5);
  ok($object->does('RoleMinimal'));
}

{
  eval "use ClassRequired;";
  like($@, qr/required_method1/);
}

done_testing;
