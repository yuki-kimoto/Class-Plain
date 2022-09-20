#ifndef __CLASS_PLAIND__FIELD_H__
#define __CLASS_PLAIN__FIELD_H__

struct FieldMeta {
  SV *name;
  ClassMeta *class;
  AV *hooks; /* NULL, or AV of raw pointers directly to FieldHook structs */
};

void ClassPlain__boot_fields(pTHX);

#endif
