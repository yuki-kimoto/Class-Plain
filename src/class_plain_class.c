/* vi: set ft=xs : */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "class_plain_class.h"
#include "class_plain_field.h"
#include "class_plain_method.h"

#include "perl-backcompat.c.inc"

ClassMeta *ClassPlain_create_class(pTHX_ IV type, SV* name) {
  ClassMeta *class_meta;
  Newx(class_meta, 1, ClassMeta);

  class_meta->name = SvREFCNT_inc(name);

  class_meta->role_names = newAV();
  class_meta->fields = newAV();
  class_meta->methods = newAV();
  class_meta->isa_empty = 0;

  return class_meta;
}

void ClassPlain_class_apply_attribute(pTHX_ ClassMeta *class_meta, const char *name, SV* value) {
  if(value && (!SvPOK(value) || !SvCUR(value))) {
    value = NULL;
  }
  
  // The isa attribute
  if (strcmp(name, "isa") == 0) {
    SV* super_class_name = value;
    
    if (value) {
      HV *superstash = gv_stashsv(super_class_name, 0);
      
      IV is_load_module;
      if (superstash) {
        // The new method
        SV** new_method = hv_fetchs(superstash, "new", 0);
        
        // The length of the classes in @ISA
        SV* super_class_isa_name = newSVpvf("%" SVf "::ISA", super_class_name);
        SAVEFREESV(super_class_isa_name);
        AV* super_class_isa = get_av(SvPV_nolen(super_class_isa_name), GV_ADD | (SvFLAGS(super_class_isa_name) & SVf_UTF8));
        IV super_class_isa_classes_length = av_count(super_class_isa);
        
        if (new_method) {
          is_load_module = 0;
        }
        else if (super_class_isa_classes_length > 0) {
          is_load_module = 0;
        }
        else {
          is_load_module = 1;
        }
      }
      else {
        is_load_module = 1;
      }
      
      // Original logic: if(!superstash || !hv_fetchs(superstash, "new", 0)) {
      if(is_load_module) {
        /* Try to `require` the module then attempt a second time */
        /* load_module() will modify the name argument and take ownership of it */
        load_module(PERL_LOADMOD_NOIMPORT, newSVsv(super_class_name), NULL, NULL);
        superstash = gv_stashsv(super_class_name, 0);
      }

      if(!superstash)
        croak("Superclass %" SVf " does not exist", super_class_name);

      // Push the super class to @ISA
      {
        SV* isa_name = newSVpvf("%" SVf "::ISA", class_meta->name);
        SAVEFREESV(isa_name);
        AV *isa = get_av(SvPV_nolen(isa_name), GV_ADD | (SvFLAGS(isa_name) & SVf_UTF8));
        av_push(isa, SvREFCNT_inc(super_class_name));
      }
    }
    else {
      class_meta->isa_empty = 1;
    }
    
  }
  // The isa attribute
  else if (strcmp(name, "does") == 0) {
    SV* role_name = value;
    ClassPlain_add_role_name(aTHX_ class_meta, role_name);
  }
  else {
    croak("Unrecognised class attribute :%s", name);
  }
}

void ClassPlain_add_role_name(pTHX_ ClassMeta* class_meta, SV* role_name) {
  AV *role_names = class_meta->role_names;
  
  if (role_name) {
    av_push(role_names, SvREFCNT_inc(role_name));
  }
}

void ClassPlain_begin_class_block(pTHX_ ClassMeta* class_meta) {
  SV* isa_name = newSVpvf("%" SVf "::ISA", class_meta->name);
  SAVEFREESV(isa_name);
  AV *isa = get_av(SvPV_nolen(isa_name), GV_ADD | (SvFLAGS(isa_name) & SVf_UTF8));
  
  if (!class_meta->isa_empty) {
    if(!av_count(isa)) {
      av_push(isa, newSVpvs("Class::Plain::Base"));
    }
  }
}

MethodMeta* ClassPlain_class_add_method(pTHX_ ClassMeta* class_meta, SV* method_name) {
  AV *methods = class_meta->methods;

  if(!method_name || !SvOK(method_name) || !SvCUR(method_name))
    croak("method_name must not be undefined or empty");

  MethodMeta* method_meta;
  Newx(method_meta, 1, MethodMeta);

  method_meta->name = SvREFCNT_inc(method_name);
  method_meta->class = class_meta;

  av_push(methods, (SV*)method_meta);

  return method_meta;
}

FieldMeta* ClassPlain_class_add_field(pTHX_ ClassMeta* class_meta, SV* field_name) {
  AV *fields = class_meta->fields;

  if(!field_name || !SvOK(field_name) || !SvCUR(field_name))
    croak("field_name must not be undefined or empty");

  U32 i;
  for(i = 0; i < av_count(fields); i++) {
    FieldMeta* field_meta = (FieldMeta* )AvARRAY(fields)[i];
    if(SvCUR(field_meta->name) < 2)
      continue;

    if(sv_eq(field_meta->name, field_name))
      croak("Cannot add another field named %" SVf, field_name);
  }

  FieldMeta* field_meta = ClassPlain_create_field(aTHX_ field_name, class_meta);

  av_push(fields, (SV*)field_meta);

  return field_meta;
}
