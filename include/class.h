#ifndef __CLASS_PLAIN__CLASS_H__
#define __CLASS_PLAIN__CLASS_H__

/* Metadata about a class */
struct ClassMeta {
  SV *name;
  AV *hooks;           /* NULL, or AV of raw pointers directly to ClassHook structs */
  AV *fields;   /* each elem is a raw pointer directly to a FieldMeta */
  AV *methods;  /* each elem is a raw pointer directly to a MethodMeta */
  IV isa_empty;
};

struct MethodMeta {
  SV *name;
  ClassMeta *class;
  /* We don't store the method body CV; leave that in the class stash */
  unsigned int is_common : 1;
};

void ClassPlain__boot_classes(pTHX);

#endif
