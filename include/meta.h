#ifndef __CLASS_PLAIN__TYPES_H__
#define __CLASS_PLAIN__TYPES_H__

#define CLASSPLAIN_ABIVERSION_MINOR 57
#define CLASSPLAIN_ABIVERSION_MAJOR 0

#define CLASSPLAIN_ABIVERSION  ((CLASSPLAIN_ABIVERSION_MAJOR << 16) | (CLASSPLAIN_ABIVERSION_MINOR))

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

struct ClassHookFuncs {
  U32 ver;  /* caller must initialise to CLASSPLAIN_VERSION */
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
  U32 ver;   /* caller must initialise to CLASSPLAIN_VERSION */
  U32 flags;
  const char *permit_hintkey;

  /* called immediately at apply time; return FALSE means it did its thing immediately, so don't store it */
  bool (*apply)(pTHX_ FieldMeta *fieldmeta, SV *value, SV **hookdata_ptr, void *funcdata);

  /* called at the end of `has` statement compiletime */
  void (*seal)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata);

  /* called as part of accessor generation */
  void (*gen_accessor_ops)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata,
          enum AccessorType type, struct AccessorGenerationCtx *ctx);
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
};

/* Function prototypes */

void ClassPlain_extend_pad_vars(pTHX_ const ClassMeta *meta);

OP *ClassPlain_newMETHSTARTOP(pTHX_ U32 flags);

OP *ClassPlain_newCOMMONMETHSTARTOP(pTHX_ U32 flags);

OP *ClassPlain_newFIELDPADOP(pTHX_ U32 flags, PADOFFSET padix, FIELDOFFSET fieldix);

SV *ClassPlain_get_obj_backingav(pTHX_ SV *self, enum ReprType repr, bool create);

/* Class API */
ClassMeta *ClassPlain_mop_create_class(pTHX_ enum MetaType type, SV *name);

ClassMeta *ClassPlain_mop_get_class_for_stash(pTHX_ HV *stash);

void ClassPlain_mop_class_set_superclass(pTHX_ ClassMeta *class, SV *superclassname);

void ClassPlain_mop_class_begin(pTHX_ ClassMeta *meta);

void ClassPlain_mop_class_seal(pTHX_ ClassMeta *meta);

MethodMeta *ClassPlain_mop_class_add_method(pTHX_ ClassMeta *meta, SV *methodname);

FieldMeta *ClassPlain_mop_class_add_field(pTHX_ ClassMeta *meta, SV *fieldname);

void ClassPlain_mop_class_apply_attribute(pTHX_ ClassMeta *classmeta, const char *name, SV *value);

void ClassPlain_register_class_attribute(pTHX_ const char *name, const struct ClassHookFuncs *funcs, void *funcdata);

/* Field API */
FieldMeta *ClassPlain_mop_create_field(pTHX_ SV *fieldname, ClassMeta *classmeta);

void ClassPlain_mop_field_seal(pTHX_ FieldMeta *fieldmeta);

SV *ClassPlain_mop_field_get_name(pTHX_ FieldMeta *fieldmeta);

void ClassPlain_mop_field_apply_attribute(pTHX_ FieldMeta *fieldmeta, const char *name, SV *value);

struct FieldHook *ClassPlain_mop_field_get_attribute(pTHX_ FieldMeta *fieldmeta, const char *name);

#endif
