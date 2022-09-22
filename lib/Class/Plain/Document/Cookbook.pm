package Class::Plain::Document::Cookbook;

1;

=encoding UTF-8

=head1 Name

C<Class::Plain::Document::Cookbook> - Cookbook of Class::Plain

=head1 Description

This is the cookbook of the L<Class::Plain>.

=head1 Use Class::Plain with Existing Classes

Use L<Class::Plain> with Existing Classes.

=head1 Other Data Structures

=head2 Array Based Object

An example of the array based object.

  use Class::Plain;
  
  class ArrayBased {
    method new : common {
      return bless [@_], ref $class || $class;
    }
    
    method push {
      my ($value) = @_;
      
      push @$self, $value;
    }
    
    method get {
      my ($index) = @_;
      
      return $self->[$index];
    }
    
    method to_array {
      return [@$self];
    }
  }
  
  my $object = ArrayBased->new(1, 2);

  $object->to_array # [1, 2]
  
  $object->push(3);
  $object->push(5);
  
  $object->get(0) # 1
  $object->get(1) # 2
  $object->get(2) # 3
  $object->get(3) # 5
  $object->to_array # [1, 2, 3, 5]

=head2 Scalar Based Object

An example of the scalar based object.

  use Class::Plain;
  
  class ScalarBased {
    method new : common {
      
      my $value = shift;
      
      return bless \$value, ref $class || $class;
    }
    
    method to_value {
      return $$value;
    }
  }
  
  my $object = ScalarBased->new;
  
  $object->push(3);
  $object->push(5);
  
  $object->get(0) # 3
  $object->get(1) # 5
  $object->to_array # [3, 5]

=head2 Scalar Based Object

=head1 Inheritance

=head2 Single Inheritance

An example of single inheritance.

  use Class::Plain;
  
  class Point {
    field x;
    field y;
    
    method new : common {
      my $self = $class->SUPER::new(@_);
      
      $self->{x} //= 0;
      $self->{y} //= 0;
      
      return $self;
    }
    
    method move {
      my ($x, $y) = @_;
      
      $self->{x} += $x;
      $self->{y} += $y;
    }
    
    method describe {
      print "A point at ($self->{x}, $self->{y})\n";
    }
  }
  
  my $point = Point->new(x => 5, y => 10);
  $point->describe;

  class Point3D : isa(Point) {
    field z;
    
    method new : common {
      my $self = $class->SUPER::new(@_);
      
      $self->{z} //= 0;
      
      return $self;
    }
    
    method move {
      my ($x, $y, $z) = @_;
      
      $self->SUPER::move($x, $y);
      $self->{z} += $z;
    }
    
    method describe {
      print "A point at ($self->{x}, $self->{y}, $self->{z})\n";
    }
  }
  
  my $point3d = Point3D->new(x => 5, y => 10, z => 15);
  $point3d->describe;

=head2 Multiple Inheritance

An example of multiple inheritance. It is used for modules using multiple inheritance such as L<DBIx::Class>.

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
    
    $object->b1 # 3
    
    $object->b2 # 4
    
    $object->ps # [1, 2, 3]
  }

=head1 Embeding Class

An example of embeding classes. Embeding class is similar to L<Corinna Role|https://github.com/Ovid/Cor/blob/master/rfc/roles.md> although the methods are embeded manually.

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
  
  $object->b1 # 3
  $object->b2 # 4
  $object->ps # [1, 2, 3]

=head1 Use Other OO Module With Class::Plain

L<Class::Plain> can be used with other OO modules.

=head2 Moo

Use L<Moo> with L<Class::Plain>.

  use Class::Plain;
  
  class Foo : isa() {
    use Moo;
    has "x" => (is => 'rw');
    
    method to_string { "String:" . $self->x }
  }

  my $object = Foo->new(x => 1);
  print $object->x . " " . $object->to_string;

=head2 Class::Accessor::Fast

Use L<Class::Accessor::Fast> with L<Class::Plain>.

  use Class::Plain;
  
  class Foo {
    use base 'Class::Accessor::Fast';
    __PACKAGE__->mk_accessors('x');
    method to_string { "String:" . $self->x }
  }
  
  my $object = Foo->new(x => 1);
  print $object->x . " " . $object->to_string;

=head2 Class::Accessor

Use L<Class::Accessor> with L<Class::Plain>.

  use Class::Plain;
  
  class Foo {
    use base 'Class::Accessor::Fast';
    __PACKAGE__->mk_accessors('x');
    method to_string { "String:" . $self->x }
  }
  
  my $object = Foo->new(x => 1);
  print $object->x . " " . $object->to_string;

=head2 Mojo::Base

Use L<Mojo::Base> with L<Class::Plain>.

  use Class::Plain;
  
  class Foo : isa() {
    use Mojo::Base -base;
    has "x";
    
    method to_string { "String:" . $self->x }
  }

  my $object = Foo->new(x => 1);
  print $object->x . " " . $object->to_string;

=head1 Weakening Field

Weaken a field.

  use Scalar::Util 'weaken';
  
  use Class::Plain;
  
  class Foo {
    field x;
    
    method weaken_x {
      weaken $self->{x};
    }
  }

=head1 Signatures

Use L<Class::Plain> with L<subroutine signatures|https://perldoc.perl.org/perlsub#Signatures>.
  
  use v5.36; # Enable signatures and other features.
  
  use Class::Plain;
  
  class Point {
    field x;
    field y;
    
    method new : common {
      my $self = $class->SUPER::new(@_);
      
      $self->{x} //= 0;
      $self->{y} //= 0;
      
      return $self;
    }
    
    # Subroutine signatures
    method move ($x = 0, $y = 0) {
      
      $self->{x} += $x;
      $self->{y} += $y;
    }
    
    method describe {
      print "A point at ($self->{x}, $self->{y})\n";
    }
  }
  
  my $point = Point->new(x => 5, y => 10);
  $point->describe;

