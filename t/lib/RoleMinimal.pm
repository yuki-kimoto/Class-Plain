use strict;
use warnings;

use Class::Plain;

role RoleMinimal {
  field x : rw;
  
  method role_foo {
    return 1;
  }

  method role_bar {
    return "role_bar";
  }
  
  method required_method1;
}
