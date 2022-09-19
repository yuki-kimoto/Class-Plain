#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2019-2022 -- leonerd@leonerd.org.uk

package Object::Pad 0.68;

use v5.14;
use warnings;

use Carp;

sub dl_load_flags { 0x01 }

require DynaLoader;
__PACKAGE__->DynaLoader::bootstrap( our $VERSION );

our $XSAPI_VERSION = "0.48";

# So that feature->import will work in `class`
require feature;
if( $] >= 5.020 ) {
   require experimental;
   require indirect if $] < 5.031009;
}

require mro;

require Object::Pad::MOP::Class;

use base 'Object::Pad::Base';

sub import
{
   my $class = shift;
   my $caller = caller;

   $class->import_into( $caller, @_ );
}

sub _import_experimental
{
   shift;
   my ( $syms, @experiments ) = @_;

   my %enabled;

   my $i = 0;
   while( $i < @$syms ) {
      my $sym = $syms->[$i];

      if( $sym eq ":experimental" ) {
         $enabled{$_}++ for @experiments;
      }
      elsif( $sym =~ m/^:experimental\((.*)\)$/ ) {
         my $tags = $1 =~ s/^\s+|\s+$//gr; # trim
         $enabled{$_}++ for split m/\s+/, $tags;
      }
      else {
         $i++;
         next;
      }

      splice @$syms, $i, 1, ();
   }

   foreach ( @experiments ) {
      $^H{"Object::Pad/experimental($_)"}++ if delete $enabled{$_};
   }

   croak "Unrecognised :experimental features @{[ keys %enabled ]}" if keys %enabled;
}

sub _import_configuration
{
   shift;
   my ( $syms ) = @_;

   # Undocumented options, purely to support Feature::Compat::Class adjusting
   # the behaviour to closer match core's  use feature 'class'

   my $i = 0;
   while( $i < @$syms ) {
      my $sym = $syms->[$i];

      if( $sym =~ m/^:config\((.*)\)$/ ) {
         my $opts = $1 =~ s/^\s+|\s+$//gr; # trim
         $^H{"Object::Pad/configure($_)"}++ for split m/\s+/, $opts;
      }
      else {
         $i++;
         next;
      }

      splice @$syms, $i, 1, ();
   }
}

sub import_into
{
   my $class = shift;
   my $caller = shift;

   $class->_import_experimental( \@_, qw( init_expr mop custom_field_attr ) );

   $class->_import_configuration( \@_ );

   my %syms = map { $_ => 1 } @_;

   # Default imports
   unless( %syms ) {
      $syms{$_}++ for qw( class role method field has);
   }

   delete $syms{$_} and $^H{"Object::Pad/$_"}++ for qw( class role method field has);

   croak "Unrecognised import symbols @{[ keys %syms ]}" if keys %syms;
}

# The universal base-class methods

sub Object::Pad::UNIVERSAL::new {
   my $class = shift;
   
   my $self = {@_};
   
   return bless $self, ref $class || $class;
}

sub Object::Pad::UNIVERSAL::_BUILDARGS
{
   shift; # $class
   return @_;
}

# Back-compat wrapper
sub Object::Pad::MOP::SlotAttr::register
{
   shift; # $class
   carp "Object::Pad::MOP::SlotAttr->register is now deprecated; use Object::Pad::MOP::FieldAttr->register instead";
   return Object::Pad::MOP::FieldAttr->register( @_ );
}


=encoding UTF-8

=head1 NAME

C<Object::Pad> - a simple syntax for lexical field-based objects

=head1 SYNOPSIS

On perl version 5.26 onwards:

   use v5.26;
   use Object::Pad;

   class Point {
      has $x :param;
      has $y :param;

     method new : common {
       my $self = bless [@_], $class;
       
       my @field_names = qw(x y);
       my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
       $self->[$field_ids{x}] = 0 unless defined $self->[$field_ids{x}];
       $self->[$field_ids{y}] = 0 unless defined $self->[$field_ids{y}];
       
       return $self;
     }

      method move ($dX, $dY) {
         $x += $dX;
         $y += $dY;
      }

      method describe () {
         print "A point at ($x, $y)\n";
      }
   }

   Point->new(x => 5, y => 10)->describe;

Or, for older perls that lack signatures:

   use Object::Pad;

   class Point {
      has $x :param;
      has $y :param;

     method new : common {
       my $self = bless [@_], $class;
       
       my @field_names = qw(x y);
       my %field_ids = map { $field_names[$_] => $_ } (0 .. @field_names - 1);
       $self->[$field_ids{x}] = 0 unless defined $self->[$field_ids{x}];
       $self->[$field_ids{y}] = 0 unless defined $self->[$field_ids{y}];
       
       return $self;
     }

      method move {
         my ($dX, $dY) = @_;
         $x += $dX;
         $y += $dY;
      }

      method describe {
         print "A point at ($x, $y)\n";
      }
   }

   Point->new(x => 5, y => 10)->describe;

=head1 DESCRIPTION

This module provides a simple syntax for creating object classes, which uses
private variables that look like lexicals as object member fields.

While most of this module has evolved into a stable state in practice, parts
remain B<experimental> because the design is still evolving, and many features
and ideas have yet to implemented. I don't yet guarantee I won't have to
change existing details in order to continue its development. Feel free to try
it out in experimental or newly-developed code, but don't complain if a later
version is incompatible with your current code and you'll have to change it.

That all said, please do get in contact if you find the module overall useful.
The more feedback you provide in terms of what features you are using, what
you find works, and what doesn't, will help the ongoing development and
hopefully eventual stability of the design. See the L</FEEDBACK> section.

=head2 Experimental Features

I<Since version 0.63.>

Some of the features of this module are currently marked as experimental. They
will provoke warnings in the C<experimental> category, unless silenced.

You can silence this with C<no warnings 'experimental'> but then that will
silence every experimental warning, which may hide others unintentionally. For
a more fine-grained approach you can instead use the import line for this
module to only silence the module's warnings selectively:

   use Object::Pad ':experimental(init_expr)';

   use Object::Pad ':experimental(mop)';

   use Object::Pad ':experimental(custom_field_attr)';

   use Object::Pad ':experimental';  # all of the above

I<Since version 0.64.>

Multiple experimental features can be enabled at once by giving multiple names
in the parens, separated by spaces:

   use Object::Pad ':experimental(init_expr mop)';

=head2 Automatic Construction

Classes are automatically provided with a constructor method, called C<new>,
which helps create the object instances. This may respond to passed arguments,
automatically assigning values of fields, and invoking other blocks of code
provided by the class. It proceeds in the following stages:

=head3 Field assignment

If any field in the class has the C<:param> attribute, then the constructor
will expect to receive its argmuents in an even-sized list of name/value
pairs. This applies even to fields inherited from the parent class or applied
roles. It is therefore a good idea to shape the parameters to the constructor
in this way in roles, and in classes if you intend your class to be extended.

The constructor will also check for required parameters (these are all the
parameters for fields that do not have default initialisation expressions). If
any of these are missing an exception is thrown.

=head1 KEYWORDS

=head2 class

   class Name :ATTRS... {
      ...
   }

   class Name :ATTRS...;

Behaves similarly to the C<package> keyword, but provides a package that
defines a new class. Such a class provides an automatic constructor method
called C<new>.

As with C<package>, an optional block may be provided. If so, the contents of
that block define the new class and the preceding package continues
afterwards. If not, it sets the class as the package context of following
keywords and definitions.

As with C<package>, an optional version declaration may be given. If so, this
sets the value of the package's C<$VERSION> variable.

   class Name VERSION { ... }

   class Name VERSION;

A single superclass is supported by the keyword C<isa>

I<Since version 0.41.>

   class Name isa BASECLASS {
      ...
   }

   class Name isa BASECLASS BASEVER {
      ...
   }

Prior to version 0.41 this was called C<extends>, which is currently
recognised as a compatibility synonym. Both C<extends> and C<isa> keywords are
now deprecated, in favour of the L</:isa> attribute which is preferred
because it follows a more standard grammar without this special-case.

One or more roles can be composed into the class by the keyword C<does>

I<Since version 0.41.>

   class Name does ROLE, ROLE,... {
      ...
   }

Prior to version 0.41 this was called C<implements>, which is currently
recognised as a compatibility synonym. Both C<implements> and C<does> keywords
are now deprecated, in favour of the L</:does> attribute which is preferred
because it follows a more standard grammar without this special-case.

An optional list of attributes may be supplied in similar syntax as for subs
or lexical variables. (These are annotations about the class itself; the
concept should not be confused with per-object-instance data, which here is
called "fields").

Whitespace is permitted within the value and is automatically trimmed, but as
standard Perl parsing rules, no space is permitted between the attribute's
name and the open parenthesis of its value:

   :attr( value here )     # is permitted
   :attr (value here)      # not permitted

The following class attributes are supported:

=head3 :isa

   :isa(CLASS)

   :isa(CLASS CLASSVER)

I<Since version 0.57.>

Declares a superclass that this class extends. At most one superclass is
supported.

If the package providing the superclass does not exist, an attempt is made to
load it by code equivalent to

   require CLASS ();

and thus it must either already exist, or be locatable via the usual C<@INC>
mechanisms.

The superclass may or may not itself be implemented by C<Object::Pad>, but if
it is not then see L<SUBCLASSING CLASSIC PERL CLASSES> for further detail on
the semantics of how this operates.

An optional version check can also be supplied; it performs the equivalent of

   BaseClass->VERSION( $ver )

=head3 :does

   :does(ROLE)

   :does(ROLE ROLEVER)

I<Since version 0.57.>

Composes a role into the class; optionally requiring a version check on the
role package. This is a newer form of the C<implements> and C<does>
keywords and should be preferred for new code.

Multiple roles can be composed by using multiple C<:does> attributes, one per
role.

The package will be loaded in a similar way to how the L</:isa> attribute is
handled.

=head2 role

   role Name :ATTRS... {
      ...
   }

   role Name :ATTRS...;

I<Since version 0.32.>

Similar to C<class>, but provides a package that defines a new role. A role
acts similar to a class in some respects, and differently in others.

Like a class, a role can have a version, and named methods.

   role Name VERSION {
      method a { ... }
      method b { ... }
   }

A role does not provide a constructor, and instances cannot directly be
constructed. A role cannot extend a class.

A role can declare that it required methods of given names from any class that
implements the role.

   role Name {
      method METHOD;
   }

I<Since version 0.57> a role can declare that it provides another role:

   role Name :does(OTHERROLE) { ... }
   role Name :does(OTHERROLE OTHERVER) { ... }

This will include all of the methods from the included role. Effectively this
means that applying the "outer" role to a class will imply applying the other
role as well.

The following role attributes are supported:

=head2 field

   field $var;

   field $var :ATTR ATTR...;

I<Since version 0.66.>

Declares that the instances of the class or role have a member field of the
given name. This member field will be accessible as a lexical variable within
any C<method> declarations in the class.

The following field attributes are supported:

=head3 :reader, :reader(NAME)

I<Since version 0.27.>

Generates a reader method to return the current value of the field. If no name
is given, the name of the field is used.

   field $x :reader;

   # equivalent to
   field $x;  method x { return $x }

=head3 :writer, :writer(NAME)

I<Since version 0.27.>

Generates a writer method to set a new value of the field from its arguments.
If no name is given, the name of the field is used prefixed by C<set_>.

   field $x :writer;

   # equivalent to
   field $x;
   method set_x { $x = shift; return $self }

I<Since version 0.28> a generated writer method will return the object
invocant itself, allowing a chaining style.

   $obj->set_x("x")
      ->set_y("y")
      ->set_z("z");

=head3 :accessor, :accessor(NAME)

I<Since version 0.53.>

Generates a combined reader-writer accessor method to set or return the value
of the field. These are only permitted for scalar fields. If no name is given,
the name of the field is used. A prefix character C<_> will be removed if
present.

This method takes either zero or one additional arguments. If an argument is
passed, the value of the field is set from this argument (even if it is
C<undef>). If no argument is passed (i.e. C<scalar @_> is false) then the
field is not modified. In either case, the value of the field is then
returned.

   field $x :accessor;

   # equivalent to
   field $x;

   method field {
      $x = shift if @_;
      return $x;
   }

=head3 :weak

I<Since version 0.44.>

Generated code which sets the value of this field will weaken it if it
contains a reference. This applies to within the constructor if C<:param> is
given, and to a C<:writer> accessor method. Note that this I<only> applies to
automatically generated code; not normal code written in regular method
bodies. If you assign into the field variable you must remember to call
C<Scalar::Util::weaken> (or C<builtin::weaken> on Perl 5.36 or above)
yourself.

=head3 :param

I<Since version 0.41.>

Sets this field to be initialised automatically in the generated constructor.
This is only permitted on scalar fields. If no name is given, the name of the
field is used. A single prefix character C<_> will be removed if present.

Any field that has C<:param> but does not have a default initialisation
expression or block becomes a required argument to the constructor. Attempting
to invoke the constructor without a named argument for this will throw an
exception. In order to make a parameter optional, make sure to give it a
default expression - even if that expression is C<undef>:

   has $x :param;          # this is required
   has $z :param;  # this is optional

Any field that has a C<:param> and an initialisation block will only run the
code in the block if required by the constructor. If a named parameter is
passed to the constructor for this field, then its code block will not be
executed.

=head2 has

   has $var;

The alias for the L</field> keyword, except that inline expressions are also
permitted.

=head2 method

   method NAME {
      ...
   }

   method NAME (SIGNATURE) {
      ...
   }

   method NAME :ATTRS... {
      ...
   }

   method NAME;

Declares a new named method. This behaves similarly to the C<sub> keyword,
except that within the body of the method all of the member fields are also
accessible. In addition, the method body will have a lexical called C<$self>
which contains the invocant object directly; it will already have been shifted
from the C<@_> array.

If the method has no body and is given simply as a name, this declares a
I<required> method for a role. Such a method must be provided by any class
that implements the role. It will be a compiletime error to combine the role
with a class that does not provide this.

The C<signatures> feature is automatically enabled for method declarations. In
this case the signature does not have to account for the invocant instance; 
that is handled directly.

   method m ($one, $two) {
      say "$self invokes method on one=$one two=$two";
   }

   ...
   $obj->m(1, 2);

A list of attributes may be supplied as for C<sub>. The most useful of these
is C<:lvalue>, allowing easy creation of read-write accessors for fields (but
see also the C<:reader> and C<:writer>> field attributes).

   class Counter {
      field $count;

      method count :lvalue { $count }
   }

   my $c = Counter->new;
   $c->count++;

Every method automatically gets the C<:method> attribute applied, which
suppresses warnings about ambiguous calls resolved to core functions if the
name of a method matches a core function.

The following additional attributes are recognised by C<Object::Pad> directly:

=head3 :override

I<Since version 0.29.>

Marks that this method expects to override another of the same name from a
superclass. It is an error at compiletime if the superclass does not provide
such a method.

=head3 :common

I<Since version 0.62.>

Marks that this method is a class-common method, instead of a regular instance
method. A class-common method may be invoked on class names instead of
instances. Within the method body there is a lexical C<$class> available,
rather than C<$self>. Because it is not associated with a particular object
instance, a class-common method cannot see instance fields.

=head1 CREPT FEATURES

While not strictly part of being an object system, this module has
nevertheless gained a number of behaviours by feature creep, as they have been
found useful.

=head2 Implied Pragmata

In order to encourage users to write clean, modern code, the body of the
C<class> block acts as if the following pragmata are in effect:

   use strict;
   use warnings;
   no indirect ':fatal';  # or  no feature 'indirect' on perl 5.32 onwards
   use feature 'signatures';

This list may be extended in subsequent versions to add further restrictions
and should not be considered exhaustive.

Further additions will only be ones that remove "discouraged" or deprecated
language features with the overall goal of enforcing a more clean modern style
within the body. As long as you write code that is in a clean, modern style
(and I fully accept that this wording is vague and subjective) you should not
find any new restrictions to be majorly problematic. Either the code will
continue to run unaffected, or you may have to make some small alterations to
bring it into a conforming style.

=head2 Yield True

A C<class> statement or block will yield a true boolean value. This means that
it can be used directly inside a F<.pm> file, avoiding the need to explicitly
yield a true value from the end of it.

=head1 SUBCLASSING CLASSIC PERL CLASSES

There are a number of details specific to the case of deriving an
C<Object::Pad> class from an existing classic Perl class that is not
implemented using C<Object::Pad>.

=head2 Storage of Instance Data

Instances will pick either the C<:repr(HASH)> or C<:repr(magic)> storage type.

=head1 STYLE SUGGESTIONS

While in no way required, the following suggestions of code style should be
noted in order to establish a set of best practices, and encourage consistency
of code which uses this module.

=head2 $VERSION declaration

While it would be nice for CPAN and other toolchain modules to parse the
embedded version declarations in C<class> statements, the current state at
time of writing (June 2020) is that none of them actually do. As such, it will
still be necessary to make a once-per-file C<$VERSION> declaration in syntax
those modules can parse.

Further note that these modules will also not parse the C<class> declaration,
so you will have to duplicate this with a C<package> declaration as well as a
C<class> keyword. This does involve repeating the package name, so is slightly
undesirable.

It is hoped that eventually upstream toolchain modules will be adapted to
accept the C<class> syntax as being sufficient to declare a package and set
its version.

See also

=over 2

=item *

L<https://github.com/Perl-Toolchain-Gang/Module-Metadata/issues/33>

=back

=head2 File Layout

Begin the file with a C<use Object::Pad> line; ideally including a
minimum-required version. This should be followed by the toplevel C<package>
and C<class> declarations for the file. As it is at toplevel there is no need
to use the block notation; it can be a unit class.

There is no need to C<use strict> or apply other usual pragmata; these will
be implied by the C<class> keyword.

   use Object::Pad 0.16;

   package My::Classname 1.23;
   class My::Classname;

   # other use statements

   # has, methods, etc.. can go here

=head2 Field Names

Field names should follow similar rules to regular lexical variables in code -
lowercase, name components separated by underscores. For tiny examples such as
"dumb record" structures this may be sufficient.

   class Tag {
      field $name  :accessor;
      field $value :accessor;
   }

=cut

1;
