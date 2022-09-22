#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Class::Plain;

class Point {
   field x;
   field y;
   
   method where { sprintf "(%d,%d)", $self->{x}, $self->{y} }
}

# nested anon method (RT132321)
SKIP: {
   skip "This causes SEGV on perl 5.16 (RT132321)", 1 if $] lt "5.018";
   class RT132321 {
      field _genvalue;

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

{
  class MyClassSignature {
    field foo : rw;
    field bar : rw;
    
    use experimental 'signatures';
    
    method set_fields ($foo, $bar = 3, @) {
      
      $self->{foo} = $foo;
      $self->{bar} = $bar;
    }
    
    my $outside = 10;
    
    method anon {
      return method ($foo, $bar = 7, @) {
        
        $self->{foo} = $foo;
        $self->{bar} = $bar;
        
        return $outside;
      };
    }
  }

  my $object = MyClassSignature->new;

  $object->set_fields(4);
  is($object->foo, 4);
  is($object->bar, 3);

  my $anon_ret = $object->anon->($object, 5);
  is($anon_ret, 10);
  is($object->foo, 5);
  is($object->bar, 7);
}

{
  class ClassAnonMethod {
     field data;

     method new : common {
       my $self = $class->SUPER::new(@_);
       
       return $self;
     }

     my $priv = method {
        "data<$self->{data}>";
     };

     method m { return $self->$priv }
  }

  {
     my $obj = ClassAnonMethod->new( data => "value" );
     is( $obj->m, "data<value>", 'method can invoke captured method ref' );
  }
}

{
  class ClassException {
     field x;
     method clear { $self->{x} = 0 }
  }

  {
     ok( !eval { ClassException->clear },
        'method on non-instance fails' );
     like( $@, qr/^Cannot invoke method on a non-instance /,
        'message from method on non-instance' );
  }
}

done_testing;
