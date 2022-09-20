#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2019-2022 -- leonerd@leonerd.org.uk

package Class::Plain 0.68;

use v5.14;
use warnings;

use Carp;

sub dl_load_flags { 0x01 }

require DynaLoader;
__PACKAGE__->DynaLoader::bootstrap( our $VERSION );

our $XSAPI_VERSION = "0.48";

use Class::Plain::Base;

sub import
{
   my $class = shift;
   my $caller = caller;

   $class->import_into( $caller, @_ );
}

sub import_into
{
   my $class = shift;
   my $caller = shift;

   my %syms = map { $_ => 1 } @_;

   # Default imports
   unless( %syms ) {
      $syms{$_}++ for qw( class role method field has);
   }

   delete $syms{$_} and $^H{"Class::Plain/$_"}++ for qw( class role method field has);

   croak "Unrecognised import symbols @{[ keys %syms ]}" if keys %syms;
}

=encoding UTF-8

=head1 NAME

C<Class::Plain> - a simple syntax for lexical field-based objects

=head1 SYNOPSIS

   use Class::Plain;

   class Point {
      has x;
      has y;

     method new : common {
       my $self = $class->SUPER::new(@_);
       
       $self->{x} //= 0;
       $self->{y} //= 0;
       
       return $self;
     }

      method move ($x, $y) {
         $self->{x} += $x;
         $self->{y} += $y;
      }

      method describe () {
         print "A point at ($self->{x}, $self->{y})\n";
      }
   }

   Point->new(x => 5, y => 10)->describe;

=head1 DESCRIPTION

This module provides a class syntax for hash-based Perl OO.

=head1 KEYWORDS

=head2 class

   class NAME : ATTRS... {
      ...
   }

   class NAME : ATTRS...;

Behaves similarly to the C<package> keyword, but provides a package that
defines a new class.

As with C<package>, an optional block may be provided. If so, the contents of
that block define the new class and the preceding package continues
afterwards. If not, it sets the class as the package context of following
keywords and definitions.

   class NAME { ... }

   class NAME;

A single supper class is supported by the C<extends> keyword or the C<isa> attribute.
   
   # Moo/Moose-ish
   class NAME extends SUPER_CLASS {
      ...
   }
   
   # Corinna-ish
   class NAME : isa(SUPER_CLASS) {
      ...
   }

If the supper class is not specified, the class inherits L<Class::Plain::Base>.

The following class attributes are supported:

=head3 isa Attribute

   : isa(CLASS)

Declares a supper class that this class extends. At most one supper class is
supported.

If the package providing the supper class does not exist, an attempt is made to
load it by code equivalent to

   require CLASS ();

and thus it must either already exist, or be locatable via the usual C<@INC>
mechanisms.

=head2 field
   
   # (Raku|Moo/Moose|Mojo::Base|Class::Accessor)-ish
   has NAME;
   
   has NAME : ATTR ATTR...;
   
   # Corinna-ish
   field NAME;
   
   field NAME : ATTR ATTR...;

Declares that the instances of the class or role have a member field of the
given name.

The following field attributes are supported:

=head3 reader Attribute

Generates a reader method to return the current value of the field. If no name
is given, the name of the field is used.

   field x :reader;
   field x :reader(x_different_name);

   # equivalent to
   field x;  method x { return $x }

=head3 writer Attribute

Generates a writer method to set a new value of the field from its arguments.
If no name is given, the name of the field is used prefixed by C<set_>.

   field x :writer;

   field x :writer(set_x_different_name);

   # equivalent to
   method set_x { $self->{x} = shift; return $self }

=head3 accessor Attribute

Generates a combined reader-writer accessor method to set or return the value
of the field. These are only permitted for scalar fields. If no name is given,
the name of the field is used.

This method takes either zero or one additional arguments. If an argument is
passed, the value of the field is set from this argument (even if it is
C<undef>). If no argument is passed (i.e. C<scalar @_> is false) then the
field is not modified. In either case, the value of the field is then
returned.

   field x : accessor;
   field x : accessor(x_different_name);

   # equivalent to
   field x;

   method field {
      $self->{x} = shift if @_;
      return $x;
   }

=head2 has
   
The alias for the L</field> keyword.

=head2 method

   method NAME {
      ...
   }

   method NAME : ATTR ATTR ... {
      ...
   }
   
Declares a new named method. This behaves similarly to the C<sub> keyword.
In addition, the method body will have a lexical called C<$self>
which contains the invocant object directly; it will already have been shifted
from the C<@_> array.

If the method has no body and is given simply as a name, this declares a
I<required> method for a role.

   method NAME;

Such a method must be provided by any class
that does the role. It will be a compiletime error to combine the role
with a class that does not provide this.

The following method attributes are supported.

=head3 common Attribute
   
   # Class method
   method new : common {
     my $self = $class->SUPER::new(@_);
     
     # ...
     
     return $self;
   }

Marks that this method is a class-common method, instead of a regular instance
method. A class-common method may be invoked on class names instead of
instances. Within the method body there is a lexical C<$class> available.
It will already have been shifted from the C<@_> array.

1;
