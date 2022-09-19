#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

my $MATCH_ARGCOUNT =
   # Perl since 5.33.6 adds got-vs-expected counts to croak message
   $] >= 5.033006 ? qr/ \(got \d+; expected \d+\)/ : "";

class Colour {
   field $red   ; # :reader            :writer; # Remove reader writer
   field $green ; # :reader(get_green) :writer; # Remove reader writer
   field $blue  ; # :accessor; # Remove accessor
   field $white ; # :accessor; # Remove accessor
   
   method red () { $self->{red} }
   method set_red ($red) { $self->{red} = $red; return $self; }

   method get_green () { $self->{green} }
   method set_green ($green) { $self->{green} = $green; return $self;  }

   method blue { if (@_) { $self->{blue} = $_[0]; return $self; } else { $self->{blue} } }
   method white { if (@_) { $self->{white} = $_[0]; return $self;  } else { $self->{white} } }

   method new : common {
     my $self = $class->SUPER::new(@_);
     
     return $self;
   }

   method rgbw {
      ( $self->{red}, $self->{green}, $self->{blue}, $self->{white} );
   }
}

# readers
{
   my $col = Colour->new(red => 50, green => 60, blue => 70, white => 80);

   is( $col->red,       50, '$col->red' );
   is( $col->get_green, 60, '$col->get_green' );
   is( $col->blue,      70, '$col->blue' );
   is( $col->white,     80, '$col->white' );


   # Reader complains if given any arguments
   my $LINE = __LINE__+1;
   ok( !defined eval { $col->red(55); 1 },
      'reader method complains if given any arguments' );
   like( $@, qr/^Too many arguments for subroutine 'Colour::red'$MATCH_ARGCOUNT(?: at \S+ line $LINE\.)?$/,
      'exception message from too many arguments to reader' );

}

# writers
{
   my $col = Colour->new;

   $col->set_red( 80 );
   is( $col->set_green( 90 ), $col, '->set_* writer returns invocant' );
   $col->blue(100);
   $col->white( 110 );

   is_deeply( [ $col->rgbw ], [ 80, 90, 100, 110 ],
      '$col->rgbw after writers' );

   # Writer complains if not given enough arguments
   my $LINE = __LINE__+1;
   ok( !defined eval { $col->set_red; 1 },
      'writer method complains if given no argument' );
   like( $@, qr/^Too few arguments for subroutine 'Colour::set_red'$MATCH_ARGCOUNT(?: at \S+ line $LINE\.)?$/,
      'exception message from too few arguments to writer' );

}

done_testing;
