#ifndef __OBJECT_PAD__CLASS_H__
#define __OBJECT_PAD__CLASS_H__

typedef struct AdjustBlock {
  CV *cv;
} AdjustBlock;

/* Metadata about a class */
struct ClassMeta {
  enum MetaType type : 8;

  FIELDOFFSET start_fieldix; /* first field index of this partial within its instance */
  FIELDOFFSET next_fieldix;  /* 1 + final field index of this partial within its instance; */

  SV *name;
  HV *stash;
  AV *hooks;           /* NULL, or AV of raw pointers directly to ClassHook structs */
  AV *direct_fields;   /* each elem is a raw pointer directly to a FieldMeta */
  AV *direct_methods;  /* each elem is a raw pointer directly to a MethodMeta */

  COP *tmpcop;         /* a COP to use during generated constructor */
  CV *methodscope;     /* a temporary CV used just during compilation of a `method` */

  union {
    /* Things that only true classes have */
    struct {
      ClassMeta *supermeta; /* superclass */
      CV *foreign_new;      /* superclass is not Class::Plain, here is the constructor */
      CV *foreign_does;     /* superclass is not Class::Plain, here is SUPER::DOES (which could be UNIVERSAL::DOES) */
    } cls; /* not 'class' or C++ compilers get upset */
  };
};

struct MethodMeta {
  SV *name;
  ClassMeta *class;
  /* We don't store the method body CV; leave that in the class stash */
  unsigned int is_common : 1;
};

#define MOP_CLASS_RUN_HOOKS(classmeta, func, ...)                                         \
  {                                                                                       \
    U32 hooki;                                                                            \
    for(hooki = 0; classmeta->hooks && hooki < av_count(classmeta->hooks); hooki++) {     \
      struct ClassHook *h = (struct ClassHook *)AvARRAY(classmeta->hooks)[hooki];         \
      if(*h->funcs->func)                                                                 \
        (*h->funcs->func)(aTHX_ classmeta, h->hookdata, h->funcdata, __VA_ARGS__);        \
    }                                                                                     \
  }

void ClassPlain__boot_classes(pTHX);

#endif
