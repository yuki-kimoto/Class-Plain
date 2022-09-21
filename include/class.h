#ifndef __CLASS_PLAIN__CLASS_H__
#define __CLASS_PLAIN__CLASS_H__

typedef struct ClassMeta ClassMeta;

#include "field.h"

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

struct ClassHookFuncs {
  U32 flags;

  /* called immediately at apply time; return FALSE means it did its thing immediately, so don't store it */
  bool (*apply)(pTHX_ ClassMeta *classmeta, SV *value, SV **hookdata_ptr, void *funcdata);

  /* called by mop_class_add_field() */
  void (*post_add_field)(pTHX_ ClassMeta *classmeta, SV *hookdata, void *funcdata, FieldMeta *fieldmeta);
};

struct ClassHook {
  const struct ClassHookFuncs *funcs;
  void *funcdata;
  SV *hookdata;
};

void ClassPlain__boot_classes(pTHX);

/* Class API */
ClassMeta *ClassPlain_mop_create_class(pTHX_ IV type, SV *name);

ClassMeta *ClassPlain_mop_get_class_for_stash(pTHX_ HV *stash);

void ClassPlain_mop_class_set_superclass(pTHX_ ClassMeta *class, SV *superclassname);

void ClassPlain_mop_class_begin(pTHX_ ClassMeta *meta);

MethodMeta *ClassPlain_mop_class_add_method(pTHX_ ClassMeta *meta, SV *methodname);

FieldMeta *ClassPlain_mop_class_add_field(pTHX_ ClassMeta *meta, SV *fieldname);

void ClassPlain_mop_class_apply_attribute(pTHX_ ClassMeta *classmeta, const char *name, SV *value);

void ClassPlain_register_class_attribute(pTHX_ const char *name, const struct ClassHookFuncs *funcs, void *funcdata);


#endif
