#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2019-2022 -- leonerd@leonerd.org.uk

package Class::Plain 0.68;

use v5.14;
use warnings;

use Carp;

use mro;

sub dl_load_flags { 0x01 }

require DynaLoader;
__PACKAGE__->DynaLoader::bootstrap( our $VERSION );

our $XSAPI_VERSION = "0.48";

use Class::Plain::Base;

sub import {
   my $class = shift;
   my $caller = caller;

   my %syms = map { $_ => 1 } @_;

   # Default imports
   unless( %syms ) {
      $syms{$_}++ for qw(class method field);
   }

   delete $syms{$_} and $^H{"Class::Plain/$_"}++ for qw( class method field);

   croak "Unrecognised import symbols @{[ keys %syms ]}" if keys %syms;
}

=encoding UTF-8

=head1 Name

C<Class::Plain> - a simple syntax for lexical field-based objects

=head1 Usage

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

     method move ($x, $y) {
        $self->{x} += $x;
        $self->{y} += $y;
     }

     method describe () {
        print "A point at ($self->{x}, $self->{y})\n";
     }
  }

  Point->new(x => 5, y => 10)->describe;

=head1 Description

This module provides a class syntax for hash-based Perl OO.

=head1 Keywords

=head2 class

   class NAME { ... }

   class NAME : ATTRS... {
      ...
   }

   class NAME;

   class NAME : ATTRS...;

Behaves similarly to the C<package> keyword, but provides a package that
defines a new class.

As with C<package>, an optional block may be provided. If so, the contents of
that block define the new class and the preceding package continues
afterwards. If not, it sets the class as the package context of following
keywords and definitions.

The following class attributes are supported:

=head3 isa Attribute

   : isa(CLASS)

Define a supper class that this class extends.

If the package providing the supper class does not exist, an attempt is made to
load it by code equivalent to

   require CLASS ();

and thus it must either already exist, or be locatable via the usual C<@INC>
mechanisms.

If the supper class is not specified, the class inherits L<Class::Plain::Base>.

=head2 field
   
   field NAME;
   
   field NAME : ATTR ATTR...;

Define fields.

The following field attributes are supported:

=head3 reader Attribute

Generates a reader method to return the current value of the field. If no name
is given, the name of the field is used.

   field x :reader;

   # equivalent to
   field x;  method x { return $x }


   field x :reader(x_different_name);

=head3 writer Attribute

Generates a writer method to set a new value of the field from its arguments.
If no name is given, the name of the field is used prefixed by C<set_>.

   field x :writer;

   # equivalent to
   method set_x {
     $self->{x} = shift;
     return $self;
   }

   field x :writer(set_x_different_name);

=head2 method

   method NAME {
      ...
   }

   method NAME : ATTR ATTR ... {
      ...
   }
   
Define a new named method. This behaves similarly to the C<sub> keyword.
In addition, the method body will have a lexical called C<$self>
which contains the invocant object directly; it will already have been shifted
from the C<@_> array.

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
instances. Within the method body there is a lexical C<$class> available instead of C<$self>.
It will already have been shifted from the C<@_> array.

1;
