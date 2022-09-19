#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

class Animal 1.23 {
   field $legs;

   method new : common {
     my $self = {@_};
     
     return bless $self, ref $class || $class;
   }
   
   method legs { $self->{legs} };
}

is( $Animal::VERSION, 1.23, 'Versioned class has $VERSION' );

class Spider 4.56 :isa(Animal) {
   method new8 : common {
     return $class->SUPER::new(legs => 8);
   }

   method describe {
      "An animal with " . $self->{legs} . " legs";
   }
}

is( $Spider::VERSION, 4.56, 'Versioned subclass has $VERSION' );

{
   my $spider = Spider->new8;
   is( $spider->describe, "An animal with 8 legs",
      'Subclassed instances work' );
}

{
   ok( !eval <<'EOPERL',
      class Antelope :isa(Animal 2.34);
EOPERL
      ':isa insufficient version fails' );
   like( $@, qr/^Animal version 2.34 required--this is only version 1.23 /,
      'message from insufficient version' );
}

# Extend before base class is sealed (RT133190)
{
   class BaseClass {
      field $_afield;

       method new : common {
         my $self = $class->SUPER::new(@_);
         
         return $self;
       }

      class SubClass :isa(BaseClass) {
         method new : common {
           my $self = $class->SUPER::new(@_);
           
           return $self;
         }
         method one { 1 }
      }
   }

   pass( 'Did not SEGV while compiling inner derived class' );
   is( SubClass->new->one, 1, 'Inner derived subclass instances can be constructed' );
}

done_testing;
