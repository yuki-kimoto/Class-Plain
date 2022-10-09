#!/usr/bin/perl

use v5.14;
use warnings;

use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

use Class::Plain;

{
  role MyRoleDeclaration {
    
  }
}

ok(1);

done_testing;
