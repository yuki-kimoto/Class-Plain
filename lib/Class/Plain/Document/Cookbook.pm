package Class::Plain::Document::Cookbook;

1;

=encoding UTF-8

=head1 Name

C<Class::Plain::Document::Cookbook> - Cookbook of Class::Plain

=head1 Description

This is the cookbook of the L<Class::Plain>.

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

