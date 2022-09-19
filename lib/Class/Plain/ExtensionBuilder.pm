#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2021 -- leonerd@leonerd.org.uk

package Class::Plain::ExtensionBuilder 0.68;

use v5.14;
use warnings;

=head1 NAME

C<Class::Plain::ExtensionBuilder> - build-time support for extensions to C<Class::Plain>

=head1 SYNOPSIS

In F<Build.PL>:

   use Class::Plain::ExtensionBuilder;

   my $build = Module::Build->new)
      ...,
      configure_requires => {
         'Class::Plain::ExtensionBuilder' => 0,
      },
   );

   Class::Plain::ExtensionBuilder->extend_module_build( $build );

   ...

=head1 DESCRIPTION

This module provides a build-time helper to assist authors writing XS modules
that provide L<Class::Plain> extensions. It prepares a L<Module::Build>-using
distribution to be able to compile it.

=cut

require Class::Plain::ExtensionBuilder_data;

=head1 METHODS

=cut

=head2 write_object_pad_h

   Class::Plain::ExtensionBuilder->write_object_pad_h

Writes the F<object_pad.h> file to the current working directory. To cause
the compiler to actually find this file, see L</extra_compiler_flags>.

=cut

sub write_object_pad_h
{
   shift;

   open my $out, ">", "object_pad.h" or
      die "Cannot open object_pad.h for writing - $!\n";

   $out->print( Class::Plain::ExtensionBuilder_data->OBJECT_PAD_H );
}

=head2 extra_compiler_flags

   @flags = Class::Plain::ExtensionBuilder->extra_compiler_flags

Returns a list of extra flags that the build scripts should add to the
compiler invocation. This enables the C compiler to find the
F<object_pad.h> file.

=cut

sub extra_compiler_flags
{
   shift;
   return "-I.";
}

=head2 extend_module_build

   Class::Plain::ExtensionBuilder->extend_module_build( $build )

A convenient shortcut for performing all the tasks necessary to make a
L<Module::Build>-based distribution use the helper.

=cut

sub extend_module_build
{
   my $self = shift;
   my ( $build ) = @_;

   eval { $self->write_object_pad_h } or do {
      warn $@;
      return;
   };

   # preserve existing flags
   my @flags = @{ $build->extra_compiler_flags };
   push @flags, $self->extra_compiler_flags;

   $build->extra_compiler_flags( @flags );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
