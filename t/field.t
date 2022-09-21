#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;
use Test::Refcount;

use Class::Plain;

use constant HAVE_DATA_DUMP => defined eval { require Data::Dump; };

class Counter {
   field count;
   
   method new : common {
     my $self = $class->SUPER::new(@_);
     
     $self->{count} //= 0;
     
     return $self;
   }

   method inc { $self->{count}++ }

   method describe { "Count is now $self->{count}" }
}

{
   my $counter = Counter->new;
   $counter->inc;
   $counter->inc;
   $counter->inc;

   is( $counter->describe, "Count is now 3",
      '$counter->describe after $counter->inc x 3' );

   # BEGIN-time initialised fields get private storage
   my $counter2 = Counter->new;
   is( $counter2->describe, "Count is now 0",
      '$counter2 field its own $count' );
}

{
   use Data::Dumper;

   class AllTheTypes {
      field scalar;

     method new : common {
       my $self = $class->SUPER::new(@_);
       
       $self->{scalar} //= 123;
       
       return $self;
     }

      method test {
         Test::More::is( $self->{scalar}, 123, '$scalar field' );
      }
   }

   my $instance = AllTheTypes->new;

   $instance->test;
}

class Colour {
   field red : reader writer;
   field green : reader(get_green) :writer;
   field blue  ;
   field white ;
   
   method set_red  { $self->{red} = shift; return $self; }

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
