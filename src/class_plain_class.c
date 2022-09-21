/* vi: set ft=xs : */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "class_plain_class.h"
#include "class_plain_field.h"
#include "class_plain_method.h"

#include "perl-backcompat.c.inc"
#include "perl-additions.c.inc"

void ClassPlain_need_PLparser(pTHX);

static ClassAttributeRegistration *classattrs = NULL;

static void Class_Plain_register_class_attribute(const char *name, const struct ClassHookFuncs *funcs, void *funcdata)
{
  ClassAttributeRegistration *reg;
  Newx(reg, 1, struct ClassAttributeRegistration);

  reg->name = name;
  reg->funcs = funcs;
  reg->funcdata = funcdata;

  reg->next  = classattrs;
  classattrs = reg;
}

void ClassPlain_class_apply_attribute(pTHX_ ClassMeta *class_meta, const char *name, SV *value)
{
  if(value && (!SvPOK(value) || !SvCUR(value)))
    value = NULL;

  ClassAttributeRegistration *reg;
  for(reg = classattrs; reg; reg = reg->next) {
    if(!strEQ(name, reg->name))
      continue;

    SV *hookdata = value;

    if(reg->funcs->apply) {
      if(!(*reg->funcs->apply)(aTHX_ class_meta, value, &hookdata, reg->funcdata))
        return;
    }

    if(!class_meta->hooks)
      class_meta->hooks = newAV();

    struct ClassHook *hook;
    Newx(hook, 1, struct ClassHook);

    hook->funcs = reg->funcs;
    hook->funcdata = reg->funcdata;
    hook->hookdata = hookdata;

    av_push(class_meta->hooks, (SV *)hook);

    if(value && value != hookdata)
      SvREFCNT_dec(value);

    return;
  }

  croak("Unrecognised class attribute :%s", name);
}

/* TODO: get attribute */

ClassMeta *ClassPlain_get_class_for_stash(pTHX_ HV *stash)
{
  GV **gvp = (GV **)hv_fetchs(stash, "META", 0);
  if(!gvp)
    croak("Unable to find ClassMeta for %" HEKf, HEKfARG(HvNAME_HEK(stash)));

  return NUM2PTR(ClassMeta *, SvUV(SvRV(GvSV(*gvp))));
}

MethodMeta *ClassPlain_class_add_method(pTHX_ ClassMeta *meta, SV *methodname)
{
  AV *methods = meta->methods;

  if(!methodname || !SvOK(methodname) || !SvCUR(methodname))
    croak("methodname must not be undefined or empty");

  MethodMeta *methodmeta;
  Newx(methodmeta, 1, MethodMeta);

  methodmeta->name = SvREFCNT_inc(methodname);
  methodmeta->class = meta;

  av_push(methods, (SV *)methodmeta);

  return methodmeta;
}

FieldMeta *ClassPlain_class_add_field(pTHX_ ClassMeta *meta, SV *field_name)
{
  AV *fields = meta->fields;

  if(!field_name || !SvOK(field_name) || !SvCUR(field_name))
    croak("field_name must not be undefined or empty");

  U32 i;
  for(i = 0; i < av_count(fields); i++) {
    FieldMeta *fieldmeta = (FieldMeta *)AvARRAY(fields)[i];
    if(SvCUR(fieldmeta->name) < 2)
      continue;

    if(sv_eq(fieldmeta->name, field_name))
      croak("Cannot add another field named %" SVf, field_name);
  }

  FieldMeta *fieldmeta = ClassPlain_create_field(field_name, meta);

  av_push(fields, (SV *)fieldmeta);

  return fieldmeta;
}

ClassMeta *ClassPlain_create_class(pTHX_ IV type, SV *name)
{
  ClassMeta *meta;
  Newx(meta, 1, ClassMeta);

  meta->name = SvREFCNT_inc(name);

  meta->hooks   = NULL;
  meta->fields = newAV();
  meta->methods = newAV();
  meta->isa_empty = 0;

  ClassPlain_need_PLparser();

  return meta;
}

void ClassPlain_class_set_superclass(pTHX_ ClassMeta *meta, SV *super_class_name)
{
  SV *isa_name = newSVpvf("%" SVf "::ISA", meta->name);
  SAVEFREESV(isa_name);
  AV *isa = get_av(SvPV_nolen(isa_name), GV_ADD | (SvFLAGS(isa_name) & SVf_UTF8));

  av_push(isa, SvREFCNT_inc(super_class_name));
}

void ClassPlain_class_begin(pTHX_ ClassMeta *meta)
{
  SV *isa_name = newSVpvf("%" SVf "::ISA", meta->name);
  SAVEFREESV(isa_name);
  AV *isa = get_av(SvPV_nolen(isa_name), GV_ADD | (SvFLAGS(isa_name) & SVf_UTF8));
  
  if (!meta->isa_empty) {
    if(!av_count(isa)) {
      av_push(isa, newSVpvs("Class::Plain::Base"));
    }
  }
}

/*******************
 * Attribute hooks *
 *******************/

#ifndef isSPACE_utf8_safe
   /* this isn't really safe but it's the best we can do */
#  define isSPACE_utf8_safe(p, e)  (PERL_UNUSED_ARG(e), isSPACE_utf8(p))
#endif

#define split_package_ver(value, pkgname, pkgversion)  S_split_package_ver(aTHX_ value, pkgname, pkgversion)
static const char *S_split_package_ver(pTHX_ SV *value, SV *pkgname, SV *pkgversion)
{
  const char *start = SvPVX(value), *p = start, *end = start + SvCUR(value);

  while(*p && !isSPACE_utf8_safe(p, end))
    p += UTF8SKIP(p);

  sv_setpvn(pkgname, start, p - start);
  if(SvUTF8(value))
    SvUTF8_on(pkgname);

  while(*p && isSPACE_utf8_safe(p, end))
    p += UTF8SKIP(p);

  if(*p) {
    /* scan_version() gets upset about trailing content. We need to extract
     * exactly what it wants
     */
    start = p;
    if(*p == 'v')
      p++;
    while(*p && strchr("0123456789._", *p))
      p++;
    SV *tmpsv = newSVpvn(start, p - start);
    SAVEFREESV(tmpsv);

    scan_version(SvPVX(tmpsv), pkgversion, FALSE);
  }

  while(*p && isSPACE_utf8_safe(p, end))
    p += UTF8SKIP(p);

  return p;
}

/* :isa */

static bool classhook_isa_apply(pTHX_ ClassMeta *class_meta, SV *value, SV **hookdata_ptr, void *_funcdata)
{
  SV* super_class_name = newSV(0);
  SV* super_class_version = newSV(0);
  SAVEFREESV(super_class_name);
  SAVEFREESV(super_class_version);
  
  if (value) {
    const char *end = split_package_ver(value, super_class_name, super_class_version);

    if(*end)
      croak("Unexpected characters while parsing :isa() attribute: %s", end);

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

    if(super_class_version && SvOK(super_class_version))
      ensure_module_version(super_class_name, super_class_version);
    
    ClassPlain_class_set_superclass(class_meta, super_class_name);
  }
  else {
    class_meta->isa_empty = 1;
  }
  
  return FALSE;
}

static const struct ClassHookFuncs classhooks_isa = {
  .apply = &classhook_isa_apply,
};

void ClassPlain__boot_classes(pTHX)
{
  Class_Plain_register_class_attribute("isa",    &classhooks_isa,    NULL);
}
