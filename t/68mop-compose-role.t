#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain ':experimental(mop)';

role TheRole
{
   method m {}
}

{
   class AClass {
     method new : common {
       my $self = $class->SUPER::new(@_);
       
       return $self;
     }
      BEGIN {
         Class::Plain::MOP::Class->for_caller->compose_role( "TheRole" );
      }
   }

   my $ameta = Class::Plain::MOP::Class->for_class( "AClass" );

   is_deeply( [ map { $_->name } $ameta->direct_roles ], [qw( TheRole )],
      'AClass meta ->direct_roles' );
   can_ok( AClass->new, qw( m ) );
}

{
   class BClass {
     method new : common {
       my $self = $class->SUPER::new(@_);
       
       return $self;
     }
      BEGIN {
         Class::Plain::MOP::Class->for_caller->compose_role(
            Class::Plain::MOP::Class->for_class( "TheRole" )
         );
      }
   }

   my $bmeta = Class::Plain::MOP::Class->for_class( "BClass" );

   is_deeply( [ map { $_->name } $bmeta->direct_roles ], [qw( TheRole )],
      'BClass meta ->direct_roles' );
   can_ok( BClass->new, qw( m ) );
}

done_testing;
