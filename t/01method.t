#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;
use Test::Refcount;

use Class::Plain;

class Point {
   has x;
   has y;
   
   method where { sprintf "(%d,%d)", $self->{x}, $self->{y} }
}

{
   my $p = Point->new(x => 10, y => 20 );
   is_oneref( $p, '$p has refcount 1 initially' );

   is( $p->where, "(10,20)", '$p->where' );
   is_oneref( $p, '$p has refcount 1 after method' );
}

# nested anon method (RT132321)
SKIP: {
   skip "This causes SEGV on perl 5.16 (RT132321)", 1 if $] lt "5.018";
   class RT132321 {
      has _genvalue;

     method new : common {
       my $self = $class->SUPER::new(@_);

       $self->{_genvalue} //= method { 123 };
       
       return $self;
     }

      method value { $self->{_genvalue}->($self) }
   }

   my $obj = RT132321->new;
   is( $obj->value, 123, '$obj->value from generated anon method' );
}

# method warns about redeclared $self (RT132428)
{
   class RT132428 {
      BEGIN {
         my $warnings = "";
         local $SIG{__WARN__} = sub { $warnings .= join "", @_; };

         ::ok( defined eval <<'EOPERL',
            method test {
               my $self = shift;
            }
            1;
EOPERL
            'method compiles OK' );

         ::like( $warnings,
            qr/^"my" variable \$self masks earlier declaration in same scope at \(eval \d+\) line 2\./,
            'warning from redeclared $self comes from correct line' );
      }
   }
}

{
  class MyClassSignature {
    use experimental 'signatures';
    
    method foo ($foo) {
      return $foo;
    }
  }

  my $foo = MyClassSignature->new;

  is($foo->foo(4), 4);
}

done_testing;
