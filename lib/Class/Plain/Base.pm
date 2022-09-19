package Class::Plain::Base;

use strict;
use warnings;

sub new {
 my $class = shift;
 
 my $self = {@_};
 
 return bless $self, ref $class || $class;
}

1;
