#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad ':experimental(mop)';

class Example {
 method new : common {
   my $self = $class->SUPER::new(@_);
   
   return $self;
 }
}

my $meta = Object::Pad::MOP::Class->for_class( "Example" );

is( $meta->name, "Example", '$meta->name' );
ok(  $meta->is_class, '$meta->is_class true' );
ok( !$meta->is_role, '$meta->is_role false' );

is_deeply( [ $meta->superclasses ], [], '$meta->superclasses' );

is_deeply( [ $meta->direct_roles ], [], '$meta->direct_roles' );
is_deeply( [ $meta->all_roles    ], [], '$meta->all_roles' );

class Example2 :isa(Example) {
 method new : common {
   my $self = $class->SUPER::new(@_);
   
   return $self;
 }
}

is_deeply( [ Object::Pad::MOP::Class->for_class( "Example2" )->superclasses ],
   [ $meta ],
   '$meta->superclasses on subclass' );

done_testing;
