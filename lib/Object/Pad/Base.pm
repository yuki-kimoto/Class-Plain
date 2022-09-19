package Object::Pad::Base;

use strict;
use warnings;

sub new {
 my $class = shift;
 
 my $self = {@_};
 
 return bless $self, ref $class || $class;
}

sub _BUILDARGS
{
   shift; # $class
   return @_;
}

1;
