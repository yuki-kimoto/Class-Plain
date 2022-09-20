#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

my $MATCH_ARGCOUNT =
   # Perl since 5.33.6 adds got-vs-expected counts to croak message
   $] >= 5.033006 ? qr/ \(got \d+; expected \d+\)/ : "";

class Colour {
   field red   ; # :reader            :writer; # Remove reader writer
   field green ; # :reader(get_green) :writer; # Remove reader writer
   field blue  ; # :accessor; # Remove accessor
   field white ; # :accessor; # Remove accessor
   
   method red { $self->{red} }
   method set_red  { $self->{red} = shift; return $self; }

   method get_green { $self->{green} }
   method set_green { $self->{green} = shift; return $self;  }

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
}

done_testing;
