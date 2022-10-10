#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

use Class::Plain;

{
  class MyClassForMyRoleDeclaration : does(RoleMinimal) {
    method foo {
      return $self->role_foo;
    }
    method required_method1 {
      return 2;
    }
  }
  
  my $object = MyClassForMyRoleDeclaration->new;
  is($object->foo, 1);
}

{
  eval "use ClassRequired;";
  like($@, qr/required_method1/);
}

done_testing;
