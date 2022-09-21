package Class::Plain::Base;

use strict;
use warnings;

sub new {
  my $class = shift;
  
  my $self = ref $_[0] ? {%$_[0]} : {@_};
  
  bless $self, ref $class || $class;
}

1;
