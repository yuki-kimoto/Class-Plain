#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;
use Test::Fatal;

use Object::Pad ':experimental(mop)';

class Example {
   has $field :accessor :param(initial_field);
   ADJUST { $field = undef }
}

my $classmeta = Object::Pad::MOP::Class->for_class( "Example" );

my $fieldmeta = $classmeta->get_field( '$field' );

is( $fieldmeta->name, "\$field", '$fieldmeta->name' );
is( $fieldmeta->sigil, "\$", '$fieldmeta->sigil' );
is( $fieldmeta->class->name, "Example", '$fieldmeta->class gives class' );

ok( $fieldmeta->has_attribute( "accessor" ), '$fieldmeta has "accessor" attribute' );
is( $fieldmeta->get_attribute_value( "accessor" ), "field",
   'value of $fieldmeta "accessor" attribute' );

is( $fieldmeta->get_attribute_value( "param" ), "initial_field",
   'value of $fieldmeta "param" attribute' );

is_deeply( [ $classmeta->fields ], [ $fieldmeta ],
   '$classmeta->fields' );

# $fieldmeta->value as accessor
{
   my $obj = Example->new;
   $obj->field("the value");

   is( $fieldmeta->value( $obj ), "the value",
      '$fieldmeta->value as accessor' );
}

# $fieldmeta->value as accessor
{
   my $obj = Example->new;

   $fieldmeta->value( $obj ) = "a new value";

   is( $obj->field, "a new value",
      '$obj->field after $fieldmeta->value as accessor' );
}

# fieldmeta on roles (RT138927)
{
   role ARole {
      has $data;
      ADJUST { $data = 42 }
   }

   my $fieldmeta = Object::Pad::MOP::Class->for_class( 'ARole' )->get_field( '$data' );
   is( $fieldmeta->name, '$data', '$fieldmeta->name for field of role' );

   class AClass :does(ARole) {
      has $data;
      ADJUST { $data = 21 }
   }

   my $obja = AClass->new;
   is( $fieldmeta->value( $obja ), 42,
      '$fieldmeta->value as accessor on role instance fetches correct field' );

   class BClass :isa(AClass) {
      has $data;
      ADJUST { $data = 63 }
   }

   my $objb = BClass->new;
   is( $fieldmeta->value( $objb ), 42,
      '$fieldmeta->value as accessor on role instance subclass fetches correct field' );
}

done_testing;
