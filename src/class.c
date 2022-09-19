/* vi: set ft=xs : */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "object_pad.h"
#include "class.h"
#include "field.h"

#undef register_class_attribute

#ifdef HAVE_DMD_HELPER
#  define WANT_DMD_API_044
#  include "DMD_helper.h"
#endif

#include "perl-backcompat.c.inc"
#include "sv_setrv.c.inc"

#include "perl-additions.c.inc"
#include "force_list_keeping_pushmark.c.inc"
#include "optree-additions.c.inc"
#include "newOP_CUSTOM.c.inc"
#include "cv_copy_flags.c.inc"

#ifdef DEBUGGING
#  define DEBUG_OVERRIDE_PLCURCOP
#  define DEBUG_SET_CURCOP_LINE(line)    CopLINE_set(PL_curcop, line)
#else
#  undef  DEBUG_OVERRIDE_PLCURCOP
#  define DEBUG_SET_CURCOP_LINE(line)
#endif

#define need_PLparser()  ObjectPad__need_PLparser(aTHX)
void ObjectPad__need_PLparser(pTHX); /* in Object/Pad.xs */

typedef struct ClassAttributeRegistration ClassAttributeRegistration;

struct ClassAttributeRegistration {
  ClassAttributeRegistration *next;

  const char *name;
  STRLEN permit_hintkeylen;

  const struct ClassHookFuncs *funcs;
  void *funcdata;
};

static ClassAttributeRegistration *classattrs = NULL;

static void register_class_attribute(const char *name, const struct ClassHookFuncs *funcs, void *funcdata)
{
  ClassAttributeRegistration *reg;
  Newx(reg, 1, struct ClassAttributeRegistration);

  reg->name = name;
  reg->funcs = funcs;
  reg->funcdata = funcdata;

  if(funcs->permit_hintkey)
    reg->permit_hintkeylen = strlen(funcs->permit_hintkey);
  else
    reg->permit_hintkeylen = 0;

  reg->next  = classattrs;
  classattrs = reg;
}

void ObjectPad_register_class_attribute(pTHX_ const char *name, const struct ClassHookFuncs *funcs, void *funcdata)
{
  if(funcs->ver < 57)
    croak("Mismatch in third-party class attribute ABI version field: module wants %d, we require >= 57\n",
        funcs->ver);
  if(funcs->ver > OBJECTPAD_ABIVERSION)
    croak("Mismatch in third-party class attribute ABI version field: attribute supplies %d, module wants %d\n",
        funcs->ver, OBJECTPAD_ABIVERSION);

  if(!name || !(name[0] >= 'A' && name[0] <= 'Z'))
    croak("Third-party class attribute names must begin with a capital letter");

  if(!funcs->permit_hintkey)
    croak("Third-party class attributes require a permit hinthash key");

  register_class_attribute(name, funcs, funcdata);
}

void ObjectPad_mop_class_apply_attribute(pTHX_ ClassMeta *classmeta, const char *name, SV *value)
{
  HV *hints = GvHV(PL_hintgv);

  if(value && (!SvPOK(value) || !SvCUR(value)))
    value = NULL;

  ClassAttributeRegistration *reg;
  for(reg = classattrs; reg; reg = reg->next) {
    if(!strEQ(name, reg->name))
      continue;

    if(reg->funcs->permit_hintkey &&
        (!hints || !hv_fetch(hints, reg->funcs->permit_hintkey, reg->permit_hintkeylen, 0)))
      continue;

    if((reg->funcs->flags & OBJECTPAD_FLAG_ATTR_NO_VALUE) && value)
      croak("Attribute :%s does not permit a value", name);
    if((reg->funcs->flags & OBJECTPAD_FLAG_ATTR_MUST_VALUE) && !value)
      croak("Attribute :%s requires a value", name);

    SV *hookdata = value;

    if(reg->funcs->apply) {
      if(!(*reg->funcs->apply)(aTHX_ classmeta, value, &hookdata, reg->funcdata))
        return;
    }

    if(!classmeta->hooks)
      classmeta->hooks = newAV();

    struct ClassHook *hook;
    Newx(hook, 1, struct ClassHook);

    hook->funcs = reg->funcs;
    hook->funcdata = reg->funcdata;
    hook->hookdata = hookdata;

    av_push(classmeta->hooks, (SV *)hook);

    if(value && value != hookdata)
      SvREFCNT_dec(value);

    return;
  }

  croak("Unrecognised class attribute :%s", name);
}

/* TODO: get attribute */

ClassMeta *ObjectPad_mop_get_class_for_stash(pTHX_ HV *stash)
{
  GV **gvp = (GV **)hv_fetchs(stash, "META", 0);
  if(!gvp)
    croak("Unable to find ClassMeta for %" HEKf, HEKfARG(HvNAME_HEK(stash)));

  return NUM2PTR(ClassMeta *, SvUV(SvRV(GvSV(*gvp))));
}

#define make_instance_fields(classmeta, backingav, roleoffset)  S_make_instance_fields(aTHX_ classmeta, backingav, roleoffset)
static void S_make_instance_fields(pTHX_ const ClassMeta *classmeta, AV *backingav, FIELDOFFSET roleoffset)
{
  assert(classmeta->type == METATYPE_ROLE || roleoffset == 0);

  if(classmeta->start_fieldix) {
    /* Superclass actually has some fields */
    assert(classmeta->type == METATYPE_CLASS);
    assert(classmeta->cls.supermeta->sealed);

    make_instance_fields(classmeta->cls.supermeta, backingav, 0);
  }

  AV *fields = classmeta->direct_fields;
  I32 nfields = av_count(fields);

  av_extend(backingav, classmeta->next_fieldix - 1 + roleoffset);

  I32 i;
  for(i = 0; i < nfields; i++) {
    av_push(backingav, newSV(0));
  }

  if(classmeta->type == METATYPE_CLASS) {
    U32 nroles;
    RoleEmbedding **embeddings = mop_class_get_direct_roles(classmeta, &nroles);

    assert(classmeta->type == METATYPE_CLASS || nroles == 0);

    for(i = 0; i < nroles; i++) {
      RoleEmbedding *embedding = embeddings[i];
      ClassMeta *rolemeta = embedding->rolemeta;

      assert(rolemeta->sealed);

      make_instance_fields(rolemeta, backingav, embedding->offset);
    }
  }
}

SV *ObjectPad_get_obj_backingav(pTHX_ SV *self, enum ReprType repr, bool create)
{
  SV *rv = SvRV(self);

  return rv;
}

#define embed_cv(cv, embedding)  S_embed_cv(aTHX_ cv, embedding)
static CV *S_embed_cv(pTHX_ CV *cv, RoleEmbedding *embedding)
{
  assert(cv);
  assert(CvOUTSIDE(cv));

  /* Perl core's cv_clone() would break in some situation here; see
   *   https://rt.cpan.org/Ticket/Display.html?id=141483
   */
  CV *embedded_cv = cv_copy_flags(cv, 0);
  SV *embeddingsv = embedding->embeddingsv;

  assert(SvTYPE(embeddingsv) == SVt_PV && SvLEN(embeddingsv) >= sizeof(RoleEmbedding));

  PAD *pad1 = PadlistARRAY(CvPADLIST(embedded_cv))[1];
  PadARRAY(pad1)[PADIX_EMBEDDING] = SvREFCNT_inc(embeddingsv);

  return embedded_cv;
}

RoleEmbedding **ObjectPad_mop_class_get_direct_roles(pTHX_ const ClassMeta *meta, U32 *nroles)
{
  assert(meta->type == METATYPE_CLASS);
  AV *roles = meta->cls.direct_roles;
  *nroles = av_count(roles);
  return (RoleEmbedding **)AvARRAY(roles);
}

RoleEmbedding **ObjectPad_mop_class_get_all_roles(pTHX_ const ClassMeta *meta, U32 *nroles)
{
  assert(meta->type == METATYPE_CLASS);
  AV *roles = meta->cls.embedded_roles;
  *nroles = av_count(roles);
  return (RoleEmbedding **)AvARRAY(roles);
}

MethodMeta *ObjectPad_mop_class_add_method(pTHX_ ClassMeta *meta, SV *methodname)
{
  AV *methods = meta->direct_methods;

  if(meta->sealed)
    croak("Cannot add a new method to an already-sealed class");

  if(!methodname || !SvOK(methodname) || !SvCUR(methodname))
    croak("methodname must not be undefined or empty");

  U32 i;
  for(i = 0; i < av_count(methods); i++) {
    MethodMeta *methodmeta = (MethodMeta *)AvARRAY(methods)[i];
    if(sv_eq(methodmeta->name, methodname)) {
      if(methodmeta->role)
        croak("Method '%" SVf "' clashes with the one provided by role %" SVf,
          SVfARG(methodname), SVfARG(methodmeta->role->name));
      else
        croak("Cannot add another method named %" SVf, methodname);
    }
  }

  MethodMeta *methodmeta;
  Newx(methodmeta, 1, MethodMeta);

  methodmeta->name = SvREFCNT_inc(methodname);
  methodmeta->class = meta;
  methodmeta->role = NULL;

  av_push(methods, (SV *)methodmeta);

  return methodmeta;
}

FieldMeta *ObjectPad_mop_class_add_field(pTHX_ ClassMeta *meta, SV *fieldname)
{
  AV *fields = meta->direct_fields;

  if(meta->next_fieldix == -1)
    croak("Cannot add a new field to a class that is not yet begun");
  if(meta->sealed)
    croak("Cannot add a new field to an already-sealed class");

  if(!fieldname || !SvOK(fieldname) || !SvCUR(fieldname))
    croak("fieldname must not be undefined or empty");

  U32 i;
  for(i = 0; i < av_count(fields); i++) {
    FieldMeta *fieldmeta = (FieldMeta *)AvARRAY(fields)[i];
    if(SvCUR(fieldmeta->name) < 2)
      continue;

    if(sv_eq(fieldmeta->name, fieldname))
      croak("Cannot add another field named %" SVf, fieldname);
  }

  FieldMeta *fieldmeta = mop_create_field(fieldname, meta);

  av_push(fields, (SV *)fieldmeta);
  meta->next_fieldix++;

  MOP_CLASS_RUN_HOOKS(meta, post_add_field, fieldmeta);

  return fieldmeta;
}

void ObjectPad_mop_class_add_required_method(pTHX_ ClassMeta *meta, SV *methodname)
{
  if(meta->type != METATYPE_ROLE)
    croak("Can only add a required method to a role");
  if(meta->sealed)
    croak("Cannot add a new required method to an already-sealed class");

  av_push(meta->requiremethods, SvREFCNT_inc(methodname));
}

#define mop_class_implements_role(meta, rolemeta)  S_mop_class_implements_role(aTHX_ meta, rolemeta)
static bool S_mop_class_implements_role(pTHX_ ClassMeta *meta, ClassMeta *rolemeta)
{
  U32 i, n;
  switch(meta->type) {
    case METATYPE_CLASS: {
      RoleEmbedding **embeddings = mop_class_get_all_roles(meta, &n);
      for(i = 0; i < n; i++)
        if(embeddings[i]->rolemeta == rolemeta)
          return true;

      break;
    }

    case METATYPE_ROLE: {
      ClassMeta **roles = (ClassMeta **)AvARRAY(meta->role.superroles);
      U32 n = av_count(meta->role.superroles);
      /* TODO: this isn't super-efficient in deep cross-linked heirarchies */
      for(i = 0; i < n; i++) {
        if(roles[i] == rolemeta)
          return true;
        if(mop_class_implements_role(roles[i], rolemeta))
          return true;
      }
      break;
    }
  }

  return false;
}

#define embed_role(class, role)  S_embed_role(aTHX_ class, role)
static RoleEmbedding *S_embed_role(pTHX_ ClassMeta *classmeta, ClassMeta *rolemeta)
{
  U32 i;

  if(classmeta->type != METATYPE_CLASS)
    croak("Can only apply to a class");
  if(rolemeta->type != METATYPE_ROLE)
    croak("Can only apply a role to a class");

  HV *srcstash = rolemeta->stash;
  HV *dststash = classmeta->stash;

  SV *embeddingsv = newSV(sizeof(RoleEmbedding));
  assert(SvTYPE(embeddingsv) == SVt_PV && SvLEN(embeddingsv) >= sizeof(RoleEmbedding));

  RoleEmbedding *embedding = (RoleEmbedding *)SvPVX(embeddingsv);

  embedding->embeddingsv = embeddingsv;
  embedding->rolemeta    = rolemeta;
  embedding->classmeta   = classmeta;
  embedding->offset      = -1;

  av_push(classmeta->cls.embedded_roles, (SV *)embedding);
  hv_store_ent(rolemeta->role.applied_classes, classmeta->name, (SV *)embedding, 0);

  U32 nmethods = av_count(rolemeta->direct_methods);
  for(i = 0; i < nmethods; i++) {
    MethodMeta *methodmeta = (MethodMeta *)AvARRAY(rolemeta->direct_methods)[i];
    SV *mname = methodmeta->name;

    HE *he = hv_fetch_ent(srcstash, mname, 0, 0);
    if(!he || !HeVAL(he) || !GvCV((GV *)HeVAL(he)))
      croak("ARGH expected to find CODE called %" SVf " in package %" SVf,
        SVfARG(mname), SVfARG(rolemeta->name));

    {
      MethodMeta *dstmethodmeta = mop_class_add_method(classmeta, mname);
      dstmethodmeta->role = rolemeta;
      dstmethodmeta->is_common = methodmeta->is_common;
    }

    GV **gvp = (GV **)hv_fetch(dststash, SvPVX(mname), SvCUR(mname), GV_ADD);
    gv_init_sv(*gvp, dststash, mname, 0);
    GvMULTI_on(*gvp);

    if(GvCV(*gvp))
      croak("Method '%" SVf "' clashes with the one provided by role %" SVf,
        SVfARG(mname), SVfARG(rolemeta->name));

    CV *newcv;
    GvCV_set(*gvp, newcv = embed_cv(GvCV((GV *)HeVAL(he)), embedding));
    CvGV_set(newcv, *gvp);
  }

  nmethods = av_count(rolemeta->requiremethods);
  for(i = 0; i < nmethods; i++) {
    av_push(classmeta->requiremethods, SvREFCNT_inc(AvARRAY(rolemeta->requiremethods)[i]));
  }

  return embedding;
}

void ObjectPad_mop_class_add_role(pTHX_ ClassMeta *dstmeta, ClassMeta *rolemeta)
{
  if(dstmeta->sealed)
    croak("Cannot add a role to an already-sealed class");
  /* Can't currently do this as it breaks t/77mop-create-role.t
  if(!rolemeta->sealed)
    croak("Cannot add a role that is not yet sealed");
   */

  if(mop_class_implements_role(dstmeta, rolemeta))
    return;

  switch(dstmeta->type) {
    case METATYPE_CLASS: {
      U32 nroles;
      if((nroles = av_count(rolemeta->role.superroles)) > 0) {
        ClassMeta **roles = (ClassMeta **)AvARRAY(rolemeta->role.superroles);
        U32 i;
        for(i = 0; i < nroles; i++)
          mop_class_add_role(dstmeta, roles[i]);
      }

      RoleEmbedding *embedding = embed_role(dstmeta, rolemeta);
      av_push(dstmeta->cls.direct_roles, (SV *)embedding);
      return;
    }

    case METATYPE_ROLE:
      av_push(dstmeta->role.superroles, (SV *)rolemeta);
      return;
  }
}

void ObjectPad_mop_class_load_and_add_role(pTHX_ ClassMeta *meta, SV *rolename, SV *rolever)
{
  HV *rolestash = gv_stashsv(rolename, 0);
  if(!rolestash || !hv_fetchs(rolestash, "META", 0)) {
    /* Try to`require` the module then attempt a second time */
    load_module(PERL_LOADMOD_NOIMPORT, newSVsv(rolename), NULL, NULL);
    rolestash = gv_stashsv(rolename, 0);
  }

  if(!rolestash)
    croak("Role %" SVf " does not exist", SVfARG(rolename));

  if(rolever && SvOK(rolever))
    ensure_module_version(rolename, rolever);

  GV **metagvp = (GV **)hv_fetchs(rolestash, "META", 0);
  ClassMeta *rolemeta = NULL;
  if(metagvp)
    rolemeta = NUM2PTR(ClassMeta *, SvUV(SvRV(GvSV(*metagvp))));

  if(!rolemeta || rolemeta->type != METATYPE_ROLE)
    croak("%" SVf " is not a role", SVfARG(rolename));

  mop_class_add_role(meta, rolemeta);
}

#define embed_fieldhook(roleh, offset)  S_embed_fieldhook(aTHX_ roleh, offset)
static struct FieldHook *S_embed_fieldhook(pTHX_ struct FieldHook *roleh, FIELDOFFSET offset)
{
  struct FieldHook *classh;
  Newx(classh, 1, struct FieldHook);

  classh->fieldix   = roleh->fieldix + offset;
  classh->fieldmeta = roleh->fieldmeta;
  classh->funcs     = roleh->funcs;
  classh->hookdata  = roleh->hookdata;

  return classh;
}

#define mop_class_apply_role(embedding)  S_mop_class_apply_role(aTHX_ embedding)
static void S_mop_class_apply_role(pTHX_ RoleEmbedding *embedding)
{
  ClassMeta *classmeta = embedding->classmeta;
  ClassMeta *rolemeta  = embedding->rolemeta;

  if(classmeta->type != METATYPE_CLASS)
    croak("Can only apply to a class");
  if(rolemeta->type != METATYPE_ROLE)
    croak("Can only apply a role to a class");

  assert(embedding->offset == -1);
  embedding->offset = classmeta->next_fieldix;

  classmeta->next_fieldix += av_count(rolemeta->direct_fields);

  /* TODO: Run an APPLY block if the role has one */
}

static void S_apply_roles(pTHX_ ClassMeta *dstmeta, ClassMeta *srcmeta)
{
  U32 nroles;
  RoleEmbedding **arr = mop_class_get_direct_roles(srcmeta, &nroles);
  U32 i;
  for(i = 0; i < nroles; i++) {
    mop_class_apply_role(arr[i]);
  }
}

static OP *pp_alias_params(pTHX)
{
  dSP;
  PADOFFSET padix = PADIX_INITFIELDS_PARAMS;

  SV *params = POPs;

  if(SvTYPE(params) != SVt_PVHV)
    RETURN;

  SAVESPTR(PAD_SVl(padix));
  PAD_SVl(padix) = SvREFCNT_inc(params);
  save_freesv(params);

  RETURN;
}

static OP *pp_croak_from_constructor(pTHX)
{
  dSP;

  /* Walk up the caller stack to find the COP of the first caller; i.e. the
   * first one that wasn't in src/class.c
   */
  I32 count = 0;
  const PERL_CONTEXT *cx;
  while((cx = caller_cx(count, NULL))) {
    const char *copfile = CopFILE(cx->blk_oldcop);
    if(!copfile|| strNE(copfile, "src/class.c")) {
      PL_curcop = cx->blk_oldcop;
      break;
    }
    count++;
  }

  croak_sv(POPs);
}

void ObjectPad_mop_class_seal(pTHX_ ClassMeta *meta)
{
  if(meta->sealed) /* idempotent */
    return;

  if(meta->type == METATYPE_CLASS &&
      meta->cls.supermeta && !meta->cls.supermeta->sealed) {
    /* Must defer sealing until superclass is sealed first
     * (RT133190)
     */
    ClassMeta *supermeta = meta->cls.supermeta;
    if(!supermeta->pending_submeta)
      supermeta->pending_submeta = newAV();
    av_push(supermeta->pending_submeta, (SV *)meta);
    return;
  }

  if(meta->type == METATYPE_CLASS)
    S_apply_roles(aTHX_ meta, meta);

  if(meta->type == METATYPE_CLASS) {
    U32 nmethods = av_count(meta->requiremethods);
    U32 i;
    for(i = 0; i < nmethods; i++) {
      SV *mname = AvARRAY(meta->requiremethods)[i];

      GV *gv = gv_fetchmeth_sv(meta->stash, mname, 0, 0);
      if(gv && GvCV(gv))
        continue;

      croak("Class %" SVf " does not provide a required method named '%" SVf "'",
        SVfARG(meta->name), SVfARG(mname));
    }
  }

  {
    U32 i;
    for(i = 0; i < av_count(meta->direct_fields); i++) {
      FieldMeta *fieldmeta = (FieldMeta *)AvARRAY(meta->direct_fields)[i];

      U32 hooki;
      for(hooki = 0; fieldmeta->hooks && hooki < av_count(fieldmeta->hooks); hooki++) {
        struct FieldHook *h = (struct FieldHook *)AvARRAY(fieldmeta->hooks)[hooki];

        if(*h->funcs->post_initfield) {
          if(!meta->fieldhooks_initfield)
            meta->fieldhooks_initfield = newAV();

          struct FieldHook *fasth;
          Newx(fasth, 1, struct FieldHook);

          fasth->fieldix   = fieldmeta->fieldix;
          fasth->fieldmeta = fieldmeta;
          fasth->funcs     = h->funcs;
          fasth->funcdata  = h->funcdata;
          fasth->hookdata  = h->hookdata;

          av_push(meta->fieldhooks_initfield, (SV *)fasth);
        }

        if(*h->funcs->post_construct) {
          if(!meta->fieldhooks_construct)
            meta->fieldhooks_construct = newAV();

          struct FieldHook *fasth;
          Newx(fasth, 1, struct FieldHook);

          fasth->fieldix   = fieldmeta->fieldix;
          fasth->fieldmeta = fieldmeta;
          fasth->funcs     = h->funcs;
          fasth->funcdata  = h->funcdata;
          fasth->hookdata  = h->hookdata;

          av_push(meta->fieldhooks_construct, (SV *)fasth);
        }
      }
    }
  }

  meta->sealed = true;

  if(meta->pending_submeta) {
    int i;
    SV **arr = AvARRAY(meta->pending_submeta);
    for(i = 0; i < av_count(meta->pending_submeta); i++) {
      ClassMeta *submeta = (ClassMeta *)arr[i];
      arr[i] = &PL_sv_undef;

      mop_class_seal(submeta);
    }

    SvREFCNT_dec(meta->pending_submeta);
    meta->pending_submeta = NULL;
  }
}

XS_INTERNAL(injected_constructor);
XS_INTERNAL(injected_constructor)
{
  dXSARGS;
  
  (void)items;
  
  XSRETURN(0);
}

XS_INTERNAL(injected_DOES)
{
  dXSARGS;
  const ClassMeta *meta = XSANY.any_ptr;
  SV *self = ST(0);
  SV *wantrole = ST(1);

  PERL_UNUSED_ARG(items);

  CV *cv_does = NULL;

  while(meta != NULL) {
    AV *roles = meta->type == METATYPE_CLASS ? meta->cls.direct_roles : NULL;
    I32 nroles = roles ? av_count(roles) : 0;

    if(!cv_does && meta->cls.foreign_does)
      cv_does = meta->cls.foreign_does;

    if(sv_eq(meta->name, wantrole)) {
      XSRETURN_YES;
    }

    int i;
    for(i = 0; i < nroles; i++) {
      RoleEmbedding *embedding = (RoleEmbedding *)AvARRAY(roles)[i];
      if(sv_eq(embedding->rolemeta->name, wantrole)) {
        XSRETURN_YES;
      }
    }

    meta = meta->type == METATYPE_CLASS ? meta->cls.supermeta : NULL;
  }

  if (cv_does) {
    /* return $self->DOES(@_); */
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(self);
    PUSHs(wantrole);
    PUTBACK;

    int count = call_sv((SV*)cv_does, G_SCALAR);

    SPAGAIN;

    bool ret = false;

    if (count)
      ret = POPi;

    FREETMPS;
    LEAVE;

    if(ret)
      XSRETURN_YES;
  }
  else {
    /* We need to also respond to Object::Pad::Base and UNIVERSAL */
    if(sv_derived_from_sv(self, wantrole, 0))
      XSRETURN_YES;
  }

  XSRETURN_NO;
}

ClassMeta *ObjectPad_mop_create_class(pTHX_ enum MetaType type, SV *name)
{
  assert(type == METATYPE_CLASS || type == METATYPE_ROLE);

  ClassMeta *meta;
  Newx(meta, 1, ClassMeta);

  meta->type = type;
  meta->name = SvREFCNT_inc(name);

  HV *stash = meta->stash = gv_stashsv(name, GV_ADD);

  meta->sealed = false;
  meta->role_is_invokable = false;
  meta->has_superclass = false;
  meta->start_fieldix = 0;
  meta->next_fieldix = -1;
  meta->hooks   = NULL;
  meta->direct_fields = newAV();
  meta->direct_methods = newAV();
  meta->parammap = NULL;
  meta->requiremethods = newAV();
  meta->repr   = REPR_AUTOSELECT;
  meta->pending_submeta = NULL;

  meta->fieldhooks_initfield = NULL;
  meta->fieldhooks_construct = NULL;

  switch(type) {
    case METATYPE_CLASS:
      meta->cls.supermeta = NULL;
      meta->cls.foreign_new = NULL;
      meta->cls.foreign_does = NULL;
      meta->cls.direct_roles = newAV();
      meta->cls.embedded_roles = newAV();
      break;

    case METATYPE_ROLE:
      meta->role.superroles = newAV();
      meta->role.applied_classes = newHV();
      break;
  }

  need_PLparser();

  meta->tmpcop = (COP *)newSTATEOP(0, NULL, NULL);
  CopFILE_set(meta->tmpcop, __FILE__);

  meta->methodscope = NULL;

  {
    /* Inject the constructor */
    SV *newname = newSVpvf("%" SVf "::new", name);
    SAVEFREESV(newname);

    HV *stash = gv_stashsv(name, 0);
    if(!stash)
      croak("Unable to find stash for class %" SVf, name);
  }

  {
    SV *doesname = newSVpvf("%" SVf "::DOES", name);
    SAVEFREESV(doesname);
    CV *doescv = newXS_flags(SvPV_nolen(doesname), injected_DOES, __FILE__, NULL, SvFLAGS(doesname) & SVf_UTF8);
    CvXSUBANY(doescv).any_ptr = meta;
  }

  {
    GV **gvp = (GV **)hv_fetchs(stash, "META", GV_ADD);
    GV *gv = *gvp;
    gv_init_pvn(gv, stash, "META", 4, 0);
    GvMULTI_on(gv);

    SV *sv;
    sv_setref_uv(sv = GvSVn(gv), "Object::Pad::MOP::Class", PTR2UV(meta));

    newCONSTSUB(meta->stash, "META", sv);
  }

  return meta;
}

void ObjectPad_mop_class_set_superclass(pTHX_ ClassMeta *meta, SV *superclassname)
{
  assert(meta->type == METATYPE_CLASS);

  if(meta->has_superclass)
    croak("Class already has a superclass, cannot add another");

  AV *isa;
  {
    SV *isaname = newSVpvf("%" SVf "::ISA", meta->name);
    SAVEFREESV(isaname);

    isa = get_av(SvPV_nolen(isaname), GV_ADD | (SvFLAGS(isaname) & SVf_UTF8));
  }

  av_push(isa, SvREFCNT_inc(superclassname));

  ClassMeta *supermeta = NULL;

  HV *superstash = gv_stashsv(superclassname, 0);
  GV **metagvp = (GV **)hv_fetchs(superstash, "META", 0);
  if(metagvp)
    supermeta = NUM2PTR(ClassMeta *, SvUV(SvRV(GvSV(*metagvp))));

  if(supermeta) {
    /* A subclass of an Object::Pad class */
    if(supermeta->type != METATYPE_CLASS)
      croak("%" SVf " is not a class", SVfARG(superclassname));

    /* If it isn't yet sealed (e.g. because we're an inner class of it),
     * seal it now
     */
    if(!supermeta->sealed)
      mop_class_seal(supermeta);

    meta->start_fieldix = supermeta->next_fieldix;
    meta->repr = supermeta->repr;
    meta->cls.foreign_new = supermeta->cls.foreign_new;

    U32 nroles;
    RoleEmbedding **embeddings = mop_class_get_all_roles(supermeta, &nroles);
    if(nroles) {
      U32 i;
      for(i = 0; i < nroles; i++) {
        RoleEmbedding *embedding = embeddings[i];
        ClassMeta *rolemeta = embedding->rolemeta;

        av_push(meta->cls.embedded_roles, (SV *)embedding);
        hv_store_ent(rolemeta->role.applied_classes, meta->name, (SV *)embedding, 0);
      }
    }
  }
  else {
    /* A subclass of a foreign class */
    meta->cls.foreign_new = fetch_superclass_method_pv(meta->stash, "new", 3, -1);
    if(!meta->cls.foreign_new)
      croak("Unable to find SUPER::new for %" SVf, superclassname);

    meta->cls.foreign_does = fetch_superclass_method_pv(meta->stash, "DOES", 4, -1);
  }

  meta->has_superclass = true;
  meta->cls.supermeta = supermeta;
}

void ObjectPad_mop_class_begin(pTHX_ ClassMeta *meta)
{
  SV *isaname = newSVpvf("%" SVf "::ISA", meta->name);
  SAVEFREESV(isaname);

  AV *isa = get_av(SvPV_nolen(isaname), GV_ADD | (SvFLAGS(isaname) & SVf_UTF8));
  if(!av_count(isa))
    av_push(isa, newSVpvs("Object::Pad::Base"));

  if(meta->type == METATYPE_CLASS &&
      meta->repr == REPR_AUTOSELECT && !meta->cls.foreign_new)
    meta->repr = REPR_NATIVE;

  meta->next_fieldix = meta->start_fieldix;
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

static bool classhook_isa_apply(pTHX_ ClassMeta *classmeta, SV *value, SV **hookdata_ptr, void *_funcdata)
{
  SV *superclassname = newSV(0), *superclassver = newSV(0);
  SAVEFREESV(superclassname);
  SAVEFREESV(superclassver);

  const char *end = split_package_ver(value, superclassname, superclassver);

  if(*end)
    croak("Unexpected characters while parsing :isa() attribute: %s", end);

  if(classmeta->type != METATYPE_CLASS)
    croak("Only a class may extend another");

  HV *superstash = gv_stashsv(superclassname, 0);
  // Original logic: if(!superstash || !hv_fetchs(superstash, "new", 0)) {
  if(!superstash) {
    /* Try to `require` the module then attempt a second time */
    /* load_module() will modify the name argument and take ownership of it */
    load_module(PERL_LOADMOD_NOIMPORT, newSVsv(superclassname), NULL, NULL);
    superstash = gv_stashsv(superclassname, 0);
  }

  if(!superstash)
    croak("Superclass %" SVf " does not exist", superclassname);

  if(superclassver && SvOK(superclassver))
    ensure_module_version(superclassname, superclassver);

  mop_class_set_superclass(classmeta, superclassname);

  return FALSE;
}

static const struct ClassHookFuncs classhooks_isa = {
  .ver   = OBJECTPAD_ABIVERSION,
  .flags = OBJECTPAD_FLAG_ATTR_MUST_VALUE,
  .apply = &classhook_isa_apply,
};

/* :does */

static bool classhook_does_apply(pTHX_ ClassMeta *classmeta, SV *value, SV **hookdata_ptr, void *_funcdata)
{
  SV *rolename = newSV(0), *rolever = newSV(0);
  SAVEFREESV(rolename);
  SAVEFREESV(rolever);

  const char *end = split_package_ver(value, rolename, rolever);

  if(*end)
    croak("Unexpected characters while parsing :does() attribute: %s", end);

  mop_class_load_and_add_role(classmeta, rolename, rolever);

  return FALSE;
}

static const struct ClassHookFuncs classhooks_does = {
  .ver   = OBJECTPAD_ABIVERSION,
  .flags = OBJECTPAD_FLAG_ATTR_MUST_VALUE,
  .apply = &classhook_does_apply,
};

void ObjectPad__boot_classes(pTHX)
{
  register_class_attribute("isa",    &classhooks_isa,    NULL);
  register_class_attribute("does",   &classhooks_does,   NULL);

#ifdef HAVE_DMD_HELPER
  DMD_ADD_ROOT((SV *)&vtbl_backingav, "the Object::Pad backing AV VTBL");
#endif
}
