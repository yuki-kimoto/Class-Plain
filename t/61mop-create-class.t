#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad ':experimental(mop)';

=pod

{
   package AClass {
      BEGIN {
         Object::Pad->import_into( "AClass" );

         my $classmeta = Object::Pad::MOP::Class->begin_class( "AClass" );

         ::is( $classmeta->name, "AClass", '$classmeta->name' );
      }

      method message { return "Hello" }
   }

   is( AClass->new->message, "Hello",
      '->begin_class can create a class' );
}

=cut

{

  my @field_names = qw(thing other);
  my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);

  class Parent {
    has $thing;
     method new : common {
       my $self = $class->SUPER::new(@_);
       
       $self->{thing} = "parent";
       
       return $self;
     }
  }

  {
     package Child {
        BEGIN {
           Object::Pad->import_into( "Child" );

           my $classmeta = Object::Pad::MOP::Class->begin_class( "Child", isa => "Parent" );

           ::is( $classmeta->name, "Child", '$classmeta->name for Child' );
        }
        has $other;
        
       method new : common {
         my $self = $class->SUPER::new(@_);
         
         $self->{other} //= "child";
         
         return $self;
       }
       
        method other { return $self->{other} }
     }

     is( Child->new->other, "child",
        '->begin_class can extend superclasses' );
  }
}

done_testing;
