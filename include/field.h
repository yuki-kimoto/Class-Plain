#ifndef __CLASS_PLAIN__FIELD_H__
#define __CLASS_PLAIN__FIELD_H__

typedef struct FieldMeta FieldMeta;

#include "class.h"

enum AccessorType {
  ACCESSOR_READER,
  ACCESSOR_WRITER,
  ACCESSOR_COMBINED,
};


struct AccessorGenerationCtx {
  FieldMeta* fieldmeta;
  OP *bodyop;       /* OP_SASSIGN for :writer, empty for :reader */
  OP *post_bodyops;
  OP *retop;        /* OP_RETURN */
};

struct FieldMeta {
  SV *name;
  ClassMeta *class;
  AV *hooks; /* NULL, or AV of raw pointers directly to FieldHook structs */
};

struct FieldHook {
  IV fieldix; /* unused when in FieldMeta->hooks; used by ClassMeta->fieldhooks_* */
  FieldMeta *fieldmeta;
  const struct FieldHookFuncs *funcs;
  void *funcdata;
  SV *hookdata;
};

struct FieldHookFuncs {
  U32 flags;

  /* called immediately at apply time; return FALSE means it did its thing immediately, so don't store it */
  bool (*apply)(pTHX_ FieldMeta *fieldmeta, SV *value, SV **hookdata_ptr, void *funcdata);

  /* called at the end of `has` statement compiletime */
  void (*seal)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata);

  /* called as part of accessor generation */
  void (*gen_accessor_ops)(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *funcdata,
          enum AccessorType type, struct AccessorGenerationCtx *ctx);
};

void ClassPlain__boot_fields(pTHX);

/* Field API */
FieldMeta *ClassPlain_mop_create_field(pTHX_ SV *fieldname, ClassMeta *classmeta);

void ClassPlain_mop_field_seal(pTHX_ FieldMeta *fieldmeta);

void ClassPlain_mop_field_apply_attribute(pTHX_ FieldMeta *fieldmeta, const char *name, SV *value);


#endif
