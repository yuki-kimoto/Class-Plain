#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

use FindBin;
use lib "$FindBin::Bin/lib";

# The multiple inheritance
{
  class MultiBase1 {
    field b1 : rw;
    
    method ps;
    
    method b1_init {

      push @{$self->ps}, 2;
      $self->{b1} = 3;
    }
  }
  
  class MultiBase2 {
    field b2 : rw;

    method ps;
    
    method b1_init {

      push @{$self->ps}, 7;
      $self->{b1} = 8;
    }
    
    method b2_init {
      
      push @{$self->ps}, 3;
      $self->{b2} = 4;
    }
  }

  class MultiClass : isa(MultiBase1) isa(MultiBase2) {
    field ps : rw;
    
    method new : common {
      my $self = $class->SUPER::new(@_);
      
      $self->{ps} //= [];
      
      $self->init;
      
      return $self;
    }
    
    method init {
      push @{$self->{ps}}, 1;
      
      $self->b1_init;
      $self->b2_init;
    }
    
    method b1_init {
      $self->next::method;
    }
    
    method b2_init {
      $self->next::method;
    }
  }
  
  my $object = MultiClass->new;
  
  is($object->b1, 3);
  is($object->b2, 4);
  is_deeply($object->ps, [1, 2, 3]);
}

# Embeding Class
{
  class EmbedBase1 {
    field b1 : rw;
    
    method ps;
    
    method init {

      push @{$self->ps}, 2;
      $self->{b1} = 3;
    }
  }
  
  class EmbedBase2 {
    field b2 : rw;

    method ps;
    
    method init {
      
      push @{$self->ps}, 3;
      $self->{b2} = 4;
    }
  }

  class EmbedClass {
    field ps : rw;
    
    method new : common {
      my $self = $class->SUPER::new(@_);
      
      $self->{ps} //= [];
      
      $self->init;
      
      return $self;
    }
    
    method init {
      push @{$self->{ps}}, 1;
      
      $self->EmbedBase1::init;
      $self->EmbedBase2::init;
    }
    
    method b1 { $self->EmbedBase1::b1(@_) }
    
    method b2 { $self->EmbedBase2::b2(@_) }
  }
  
  my $object = EmbedClass->new;
  
  is_deeply($object->b1, 3);
  is_deeply($object->b2, 4);
  is_deeply($object->ps, [1, 2, 3]);
}

# The empty inheritance
{
  class EmptyInheritance : isa() {
  }
  
  is_deeply(\@EmptyInheritance::ISA, []);
}

# The own super class
{
  class EmptyInheritance : isa() {
    push @EmptyInheritance::ISA, 'MyBase';
  }
  
  is_deeply(\@EmptyInheritance::ISA, ['MyBase']);
}

{
  class Animal {
    our $VERSION = 1.23;
    field legs;
    method legs { $self->{legs} };
  }

  is( $Animal::VERSION, 1.23, 'Versioned class field VERSION' );

  class Spider : isa(Animal) {
    our $VERSION = 4.56;
     method new8 : common {
       return $class->SUPER::new(legs => 8);
     }

     method describe {
        "An animal with " . $self->{legs} . " legs";
     }
  }

  is( $Spider::VERSION, 4.56, 'Versioned subclass field VERSION' );

  {
     my $spider = Spider->new8;
     is( $spider->describe, "An animal with 8 legs",
        'Subclassed instances work' );
  }

  # Extend before base class is sealed (RT133190)
  {
     class BaseClass {
        field _afield;

         method new : common {
           my $self = $class->SUPER::new(@_);
           
           return $self;
         }

        class SubClass : isa(BaseClass) {
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
}

{
  class BaseClassic {
     field data;

     method new : common {
       my $self = $class->SUPER::new(@_);
       
       $self->{data} //= 123;
       
       return $self;
     }
  }

  package ExtendedClassic {
     use base qw( BaseClassic );

     sub moremethod { return 456 }
  }

  my $obj = ExtendedClassic->new;
  isa_ok( $obj, "ExtendedClassic", '$obj' );

  is( $obj->moremethod, 456, '$obj field methods from ExtendedClassic' );
}

{
  class ModuleClassIsaUse : isa(ModuleClassIsa) {
    
  }
  
  my $object = ModuleClassIsaUse->new(x => 1);
  is($object->x, 1);
  $object->set_y(2);
  is($object->{y}, 2);
  $object->z(3);
  is($object->z, 3);
}

# Symbol Exsiting
{
  {
    {
      package SymbolExist;
      
      class SymbolExistInherit : isa(SymbolExist) {
        
      }
    }
    
    my $object = SymbolExistInherit->new(x => 1);
    is($object->x, 1);
    $object->set_y(2);
    is($object->{y}, 2);
    $object->z(3);
    is($object->z, 3);
  }

  {
    {
      package SymbolExistHasNew;
      
      sub new { 1 }
      
      class SymbolExistHasNewInherit : isa(SymbolExistHasNew) {
        
      }
    }
    
    is(SymbolExistHasNewInherit->new, 1);
  }

  {
    {
      use SymbolExistHasISASuper;
      
      {
        package SymbolExistHasISA;
        use base 'SymbolExistHasISASuper';
        sub foo { 2 }
      }
      
      
      class SymbolExistHasISAInherit : isa(SymbolExistHasISA) {
        
      }
    }
    
    is(SymbolExistHasISAInherit->foo, 2);
  }
}


done_testing;
