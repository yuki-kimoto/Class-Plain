package Class::Plain::Document::Cookbook;

1;

=encoding UTF-8

=head1 Name

C<Class::Plain::Document::Cookbook> - Cookbook of Class::Plain

=head1 Description

This is the cookbook of the C<Class::Plain>.

=head1 Use Other OO Module With Class::Plain

C<Class::Plain> can be used with other OO modules.

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

