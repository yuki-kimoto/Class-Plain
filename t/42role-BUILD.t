#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use Object::Pad;

my @ADJUST;

role ARole {
  ADJUST { push @ADJUST, "ARole" }
}

class AClass :does(ARole) {
  ADJUST { push @ADJUST, "AClass" }
}

{
   undef @ADJUST;

   AClass->new;

   is_deeply( \@ADJUST, [qw( ARole AClass )],
      'Roles are adjusted before their implementing classes' );
}

done_testing;
