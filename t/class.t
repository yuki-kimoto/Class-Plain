#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

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

# The multiple inheritance
{
  class MultiBase1 {
    field ps;
    field b1;
    
    method b1_init {

      push @{$self->{ps}}, 2;
      $self->{b1} = 3;
    }
  }
  
  class MultiBase2 {
    field ps;
    field b2;
    
    method b1_init {

      push @{$self->{ps}}, 7;
      $self->{b1} = 8;
    }
    
    method b2_init {
      
      push @{$self->{ps}}, 3;
      $self->{b2} = 4;
    }
  }

  class MultiClass : isa(MultiBase1) isa(MultiBase2) {
    field ps;
    
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
  
  is_deeply($object->{b1}, 3);
  is_deeply($object->{b2}, 4);
  is_deeply($object->{ps}, [1, 2, 3]);
}

# The multiple inheritance
{
  class ImportBase1 {
    field ps;
    field b1;
    
    method init {

      push @{$self->{ps}}, 2;
      $self->{b1} = 3;
    }
  }
  
  class ImportBase2 {
    field ps;
    field b2;
    
    method init {
      
      push @{$self->{ps}}, 3;
      $self->{b2} = 4;
    }
  }

  class ImportClass {
    field ps;
    
    method new : common {
      my $self = $class->SUPER::new(@_);
      
      $self->{ps} //= [];
      
      $self->init;
      
      return $self;
    }
    
    method init {
      push @{$self->{ps}}, 1;
      
      $self->ImportBase1::init;
      $self->ImportBase2::init;
    }
  }
  
  my $object = ImportClass->new;
  
  is_deeply($object->{b1}, 3);
  is_deeply($object->{b2}, 4);
  is_deeply($object->{ps}, [1, 2, 3]);
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

done_testing;
