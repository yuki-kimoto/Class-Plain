use strict;
use warnings;

use Class::Plain;

role RoleMinimal {
  method role_foo {
    return 1;
  }
  
  method required_method1;
}
