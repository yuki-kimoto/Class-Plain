#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;
use Test::Fatal;

use Class::Plain ':experimental(mop)';

class Example {
     method new : common {
       my $self = $class->SUPER::new(@_);
       
       return $self;
     }

   method m { }
}

my $classmeta = Class::Plain::MOP::Class->for_class( "Example" );

my $methodmeta_new = $classmeta->get_direct_method( 'new' );
my $methodmeta = $classmeta->get_direct_method( 'm' );

is( $methodmeta->name, "m", '$methodmeta->name' );
is( $methodmeta->class->name, "Example", '$methodmeta->class gives class' );
ok( !$methodmeta->is_common, '$methodmeta->is_common' );

is( $classmeta->get_method( 'm' )->name, "m", '$classmeta->get_method' );

is_deeply( [ $classmeta->direct_methods ], [ $methodmeta_new, $methodmeta ],
   '$classmeta->direct_methods' );

is_deeply( [ $classmeta->all_methods ], [ $methodmeta_new, $methodmeta ],
   '$classmeta->all_methods' );

class SubClass :isa(Example) {}

ok( defined Class::Plain::MOP::Class->for_class( "SubClass" )->get_method( 'm' ),
   'Subclass can ->get_method' );

# subclass with overridden method
{
   class WithOverride :isa(Example) {
     method new : common {
       my $self = $class->SUPER::new(@_);
       
       return $self;
     }
      method m { "different" }
   }

   my @methodmetas = Class::Plain::MOP::Class->for_class( "WithOverride" )->all_methods;

   is( scalar @methodmetas, 2, 'overridden method is not duplicated' );
}

# :common methods
{
   class BClass {
     method new : common {
       my $self = $class->SUPER::new(@_);
       
       return $self;
     }
      method cm :common { }
   }

   my $classmeta = Class::Plain::MOP::Class->for_class( "BClass" );

   my $methodmeta = $classmeta->get_direct_method( 'cm' );

   is( $methodmeta->name, "cm", '$methodmeta->name for :common' );
   is( $methodmeta->class->name, "BClass", '$methodmeta->class gives class for :common' );
   ok( $methodmeta->is_common, '$methodmeta->is_common for :common' );
}

done_testing;
