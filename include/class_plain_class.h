#ifndef CLASS_PLAIN_CLASS_H
#define CLASS_PLAIN_CLASS_H

typedef struct ClassMeta ClassMeta;
typedef struct ClassAttributeRegistration ClassAttributeRegistration;

#include "class_plain_method.h"
#include "class_plain_field.h"

/* Metadata about a class */
struct ClassMeta {
  SV *name;
  AV *hooks;           /* NULL, or AV of raw pointers directly to ClassHook structs */
  AV *fields;   /* each elem is a raw pointer directly to a FieldMeta */
  AV *methods;  /* each elem is a raw pointer directly to a MethodMeta */
  IV isa_empty;
};

struct ClassHookFuncs {
  U32 flags;

  /* called immediately at apply time; return FALSE means it did its thing immediately, so don't store it */
  bool (*apply)(pTHX_ ClassMeta *class_meta, SV *value, SV **hookdata_ptr, void *funcdata);

  /* called by mop_class_add_field() */
  void (*post_add_field)(pTHX_ ClassMeta *class_meta, SV *hookdata, void *funcdata, FieldMeta *fieldmeta);
};

struct ClassHook {
  const struct ClassHookFuncs *funcs;
  void *funcdata;
  SV *hookdata;
};

struct ClassAttributeRegistration {
  ClassAttributeRegistration *next;
  const char *name;
  const struct ClassHookFuncs *funcs;
  void *funcdata;
};


void ClassPlain__boot_classes(pTHX);

/* Class API */
ClassMeta *ClassPlain_create_class(pTHX_ IV type, SV *name);

ClassMeta *ClassPlain_get_class_for_stash(pTHX_ HV *stash);

void ClassPlain_class_set_superclass(pTHX_ ClassMeta *class, SV *superclassname);

void ClassPlain_begin_class_block(pTHX_ ClassMeta *meta);

MethodMeta *ClassPlain_class_add_method(pTHX_ ClassMeta *meta, SV *methodname);

FieldMeta *ClassPlain_class_add_field(pTHX_ ClassMeta *meta, SV *fieldname);

void ClassPlain_class_apply_attribute(pTHX_ ClassMeta *class_meta, const char *name, SV *value);

void ClassPlain_register_class_attribute(pTHX_ const char *name, const struct ClassHookFuncs *funcs, void *funcdata);


#endif
