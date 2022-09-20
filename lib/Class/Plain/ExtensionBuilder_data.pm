package Class::Plain::ExtensionBuilder_data 0.68;

use v5.14;
use warnings;

# The contents of the "object_pad.h" file
my $object_pad_h = do {
   local $/;
   readline DATA;
};
sub OBJECT_PAD_H() { $object_pad_h }

0x55AA;

__DATA__
#ifndef __OBJECT_PAD__TYPES_H__
#define __OBJECT_PAD__TYPES_H__

#define OBJECTPAD_ABIVERSION_MINOR 57
#define OBJECTPAD_ABIVERSION_MAJOR 0

#define OBJECTPAD_ABIVERSION  ((OBJECTPAD_ABIVERSION_MAJOR << 16) | (OBJECTPAD_ABIVERSION_MINOR))

/* A FIELDOFFSET is an offset within the AV of an object instance */
typedef IV FIELDOFFSET;

typedef struct ClassMeta ClassMeta;
typedef struct FieldMeta FieldMeta;
typedef struct MethodMeta MethodMeta;

enum AccessorType {
  ACCESSOR,
  ACCESSOR_READER,
  ACCESSOR_WRITER,
  ACCESSOR_LVALUE_MUTATOR,
  ACCESSOR_COMBINED,
};

struct AccessorGenerationCtx {
  PADOFFSET padix;
  OP *bodyop;       /* OP_SASSIGN for :writer, empty for :reader */
  OP *post_bodyops;
  OP *retop;        /* OP_RETURN */
};

enum {
  OBJECTPAD_FLAG_ATTR_NO_VALUE = (1<<0),
  OBJECTPAD_FLAG_ATTR_MUST_VALUE = (1<<1),
};

struct ClassHookFuncs {
  U32 ver;  /* caller must initialise to OBJECTPAD_VERSION */
  U32 flags;
  const char *permit_hintkey;

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

struct FieldHookFuncs {
  U32 ver;   /* caller must initialise to OBJECTPAD_VERSION */
  U32 flags;
  const char *permit_hintkey;

  /* called immediately at apply time; return FALSE means it did its thing immediately, so don't store it */
  bool (*apply)(pTHX_ FieldMeta *fieldmeta, SV *value, SV **hookdata_ptr, void *funcdata);

  /* called at the end of `has` statement compiletime */
  void (*seal)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata);

  /* called as part of accessor generation */
  void (*gen_accessor_ops)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata,
          enum AccessorType type, struct AccessorGenerationCtx *ctx);

  /* called by constructor */
  void (*post_initfield)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata, SV *field);
  void (*post_construct)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata, SV *field);
};

struct FieldHook {
  FIELDOFFSET fieldix; /* unused when in FieldMeta->hooks; used by ClassMeta->fieldhooks_* */
  FieldMeta *fieldmeta;
  const struct FieldHookFuncs *funcs;
  void *funcdata;
  SV *hookdata;
};

enum MetaType {
  METATYPE_CLASS,
};

enum ReprType {
  REPR_NATIVE,       /* instances are in native format - blessed AV as backing */
  REPR_HASH,         /* instances are blessed HASHes; our backing lives in $self->{"Class::Plain/slots"} */
  REPR_MAGIC,        /* instances store backing AV via magic; superconstructor must be foreign */

  REPR_AUTOSELECT,   /* pick one of the above depending on foreign_new and SvTYPE()==SVt_PVHV */
};

/* Special pad indexes within `method` CVs */
enum {
  PADIX_SELF = 1,
  PADIX_SLOTS = 2,

  /* for role methods */
  PADIX_EMBEDDING = 3,

  /* during initfields */
  PADIX_INITFIELDS_PARAMS = 4,
};

/* Function prototypes */

#define extend_pad_vars(meta)  ClassPlain_extend_pad_vars(aTHX_ meta)
void ClassPlain_extend_pad_vars(pTHX_ const ClassMeta *meta);

#define newMETHSTARTOP(flags)  ClassPlain_newMETHSTARTOP(aTHX_ flags)
OP *ClassPlain_newMETHSTARTOP(pTHX_ U32 flags);

#define newCOMMONMETHSTARTOP(flags)  ClassPlain_newCOMMONMETHSTARTOP(aTHX_ flags)
OP *ClassPlain_newCOMMONMETHSTARTOP(pTHX_ U32 flags);

/* op_private flags on FIELDPAD ops */
enum {
  OPpFIELDPAD_SV,  /* has $x */
  OPpFIELDPAD_AV,  /* has @y */
  OPpFIELDPAD_HV,  /* has %z */
};

#define newFIELDPADOP(flags, padix, fieldix)  ClassPlain_newFIELDPADOP(aTHX_ flags, padix, fieldix)
OP *ClassPlain_newFIELDPADOP(pTHX_ U32 flags, PADOFFSET padix, FIELDOFFSET fieldix);

#define get_obj_backingav(self, repr, create)  ClassPlain_get_obj_backingav(aTHX_ self, repr, create)
SV *ClassPlain_get_obj_backingav(pTHX_ SV *self, enum ReprType repr, bool create);

/* Class API */
#define mop_create_class(type, name)  ClassPlain_mop_create_class(aTHX_ type, name)
ClassMeta *ClassPlain_mop_create_class(pTHX_ enum MetaType type, SV *name);

#define mop_get_class_for_stash(stash)  ClassPlain_mop_get_class_for_stash(aTHX_ stash)
ClassMeta *ClassPlain_mop_get_class_for_stash(pTHX_ HV *stash);

#define mop_class_set_superclass(class, super)  ClassPlain_mop_class_set_superclass(aTHX_ class, super)
void ClassPlain_mop_class_set_superclass(pTHX_ ClassMeta *class, SV *superclassname);

#define mop_class_begin(meta)  ClassPlain_mop_class_begin(aTHX_ meta)
void ClassPlain_mop_class_begin(pTHX_ ClassMeta *meta);

#define mop_class_seal(meta)  ClassPlain_mop_class_seal(aTHX_ meta)
void ClassPlain_mop_class_seal(pTHX_ ClassMeta *meta);

#define mop_class_load_and_add_role(class, rolename, rolever)  ClassPlain_mop_class_load_and_add_role(aTHX_ class, rolename, rolever)
void ClassPlain_mop_class_load_and_add_role(pTHX_ ClassMeta *class, SV *rolename, SV *rolever);

#define mop_class_add_role(class, role)  ClassPlain_mop_class_add_role(aTHX_ class, role)
void ClassPlain_mop_class_add_role(pTHX_ ClassMeta *class, ClassMeta *role);

#define mop_class_add_method(class, methodname)  ClassPlain_mop_class_add_method(aTHX_ class, methodname)
MethodMeta *ClassPlain_mop_class_add_method(pTHX_ ClassMeta *meta, SV *methodname);

#define mop_class_add_field(class, fieldname)  ClassPlain_mop_class_add_field(aTHX_ class, fieldname)
FieldMeta *ClassPlain_mop_class_add_field(pTHX_ ClassMeta *meta, SV *fieldname);

#define mop_class_add_ADJUST(class, cv)  ClassPlain_mop_class_add_ADJUST(aTHX_ class, cv)
void ClassPlain_mop_class_add_ADJUST(pTHX_ ClassMeta *meta, CV *cv);

#define mop_class_add_required_method(class, methodname)  ClassPlain_mop_class_add_required_method(aTHX_ class, methodname)
void ClassPlain_mop_class_add_required_method(pTHX_ ClassMeta *meta, SV *methodname);

#define mop_class_apply_attribute(classmeta, name, value)  ClassPlain_mop_class_apply_attribute(aTHX_ classmeta, name, value)
void ClassPlain_mop_class_apply_attribute(pTHX_ ClassMeta *classmeta, const char *name, SV *value);

#define register_class_attribute(name, funcs, funcdata)  ClassPlain_register_class_attribute(aTHX_ name, funcs, funcdata)
void ClassPlain_register_class_attribute(pTHX_ const char *name, const struct ClassHookFuncs *funcs, void *funcdata);

/* Field API */
#define mop_create_field(fieldname, classmeta)  ClassPlain_mop_create_field(aTHX_ fieldname, classmeta)
FieldMeta *ClassPlain_mop_create_field(pTHX_ SV *fieldname, ClassMeta *classmeta);

#define mop_field_seal(fieldmeta)  ClassPlain_mop_field_seal(aTHX_ fieldmeta)
void ClassPlain_mop_field_seal(pTHX_ FieldMeta *fieldmeta);

#define mop_field_get_name(fieldmeta)  ClassPlain_mop_field_get_name(aTHX_ fieldmeta)
SV *ClassPlain_mop_field_get_name(pTHX_ FieldMeta *fieldmeta);

#define mop_field_get_sigil(fieldmeta)  ClassPlain_mop_field_get_sigil(aTHX_ fieldmeta)
char ClassPlain_mop_field_get_sigil(pTHX_ FieldMeta *fieldmeta);

#define mop_field_apply_attribute(fieldmeta, name, value)  ClassPlain_mop_field_apply_attribute(aTHX_ fieldmeta, name, value)
void ClassPlain_mop_field_apply_attribute(pTHX_ FieldMeta *fieldmeta, const char *name, SV *value);

#define mop_field_get_attribute(fieldmeta, name)  ClassPlain_mop_field_get_attribute(aTHX_ fieldmeta, name)
struct FieldHook *ClassPlain_mop_field_get_attribute(pTHX_ FieldMeta *fieldmeta, const char *name);

#define mop_field_get_attribute_values(fieldmeta, name)  ClassPlain_mop_field_get_attribute_values(aTHX_ fieldmeta, name)
AV *ClassPlain_mop_field_get_attribute_values(pTHX_ FieldMeta *fieldmeta, const char *name);

#define mop_field_get_default_sv(fieldmeta)  ClassPlain_mop_field_get_default_sv(aTHX_ fieldmeta)
SV *ClassPlain_mop_field_get_default_sv(pTHX_ FieldMeta *fieldmeta);

#define mop_field_set_default_sv(fieldmeta, sv)  ClassPlain_mop_field_set_default_sv(aTHX_ fieldmeta, sv)
void ClassPlain_mop_field_set_default_sv(pTHX_ FieldMeta *fieldmeta, SV *sv);

#define register_field_attribute(name, funcs, funcdata)  ClassPlain_register_field_attribute(aTHX_ name, funcs, funcdata)
void ClassPlain_register_field_attribute(pTHX_ const char *name, const struct FieldHookFuncs *funcs, void *funcdata);


#endif
