#!/usr/bin/perl

use v5.14;
use warnings;

use FindBin;

use lib "$FindBin::Bin/lib";

use Test::More;

use Class::Plain;

# B module has the class keyword
use B;

use MyKeyword;

class Foo {
  # B module has the class keyword
  use B;

  use MyKeyword;
}

ok(1);

done_testing;
