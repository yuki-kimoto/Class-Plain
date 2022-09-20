/* vi: set ft=xs : */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "object_pad.h"
#include "class.h"
#include "field.h"

#include "perl-backcompat.c.inc"
#include "perl-additions.c.inc"
#include "force_list_keeping_pushmark.c.inc"
#include "optree-additions.c.inc"
#include "make_argcheck_ops.c.inc"
#include "newOP_CUSTOM.c.inc"

#define need_PLparser()  ClassPlain__need_PLparser(aTHX)
void ClassPlain__need_PLparser(pTHX); /* in Class/Plain.xs */

FieldMeta *ClassPlain_mop_create_field(pTHX_ SV *fieldname, ClassMeta *classmeta)
{
  FieldMeta *fieldmeta;
  Newx(fieldmeta, 1, FieldMeta);

  assert(classmeta->next_fieldix > -1);

  fieldmeta->name = SvREFCNT_inc(fieldname);
  fieldmeta->class = classmeta;
  fieldmeta->fieldix = classmeta->next_fieldix;
  fieldmeta->defaultsv = NULL;
  fieldmeta->defaultexpr = NULL;
  fieldmeta->paramname = NULL;

  fieldmeta->hooks = NULL;

  return fieldmeta;
}

SV *ClassPlain_mop_field_get_name(pTHX_ FieldMeta *fieldmeta)
{
  return fieldmeta->name;
}

typedef struct FieldAttributeRegistration FieldAttributeRegistration;

struct FieldAttributeRegistration {
  FieldAttributeRegistration *next;

  const char *name;
  STRLEN permit_hintkeylen;

  const struct FieldHookFuncs *funcs;
  void *funcdata;
};

static FieldAttributeRegistration *fieldattrs = NULL;

static void ClassPlain_register_field_attribute(const char *name, const struct FieldHookFuncs *funcs, void *funcdata)
{
  FieldAttributeRegistration *reg;
  Newx(reg, 1, struct FieldAttributeRegistration);

  reg->name     = name;
  reg->funcs    = funcs;
  reg->funcdata = funcdata;

  if(funcs->permit_hintkey)
    reg->permit_hintkeylen = strlen(funcs->permit_hintkey);
  else
    reg->permit_hintkeylen = 0;

  reg->next = fieldattrs;
  fieldattrs = reg;
}

void ClassPlain_mop_field_apply_attribute(pTHX_ FieldMeta *fieldmeta, const char *name, SV *value)
{
  HV *hints = GvHV(PL_hintgv);

  if(value && (!SvPOK(value) || !SvCUR(value)))
    value = NULL;

  FieldAttributeRegistration *reg;
  for(reg = fieldattrs; reg; reg = reg->next) {
    if(!strEQ(name, reg->name))
      continue;

    if(reg->funcs->permit_hintkey &&
       (!hints || !hv_fetch(hints, reg->funcs->permit_hintkey, reg->permit_hintkeylen, 0)))
      continue;

    break;
  }

  if(!reg)
    croak("Unrecognised field attribute :%s", name);

  if((reg->funcs->flags & OBJECTPAD_FLAG_ATTR_NO_VALUE) && value)
    croak("Attribute :%s does not permit a value", name);
  if((reg->funcs->flags & OBJECTPAD_FLAG_ATTR_MUST_VALUE) && !value)
    croak("Attribute :%s requires a value", name);

  SV *hookdata = value;

  if(reg->funcs->apply) {
    if(!(*reg->funcs->apply)(aTHX_ fieldmeta, value, &hookdata, reg->funcdata))
      return;
  }

  if(hookdata && hookdata == value)
    SvREFCNT_inc(hookdata);

  if(!fieldmeta->hooks)
    fieldmeta->hooks = newAV();

  struct FieldHook *hook;
  Newx(hook, 1, struct FieldHook);

  hook->funcs = reg->funcs;
  hook->hookdata = hookdata;
  hook->funcdata = reg->funcdata;

  av_push(fieldmeta->hooks, (SV *)hook);
}

struct FieldHook *ClassPlain_mop_field_get_attribute(pTHX_ FieldMeta *fieldmeta, const char *name)
{
  COPHH *cophh = CopHINTHASH_get(PL_curcop);

  /* First, work out what hookfuncs the name maps to */

  FieldAttributeRegistration *reg;
  for(reg = fieldattrs; reg; reg = reg->next) {
    if(!strEQ(name, reg->name))
      continue;

    if(reg->funcs->permit_hintkey &&
        !cophh_fetch_pvn(cophh, reg->funcs->permit_hintkey, reg->permit_hintkeylen, 0, 0))
      continue;

    break;
  }

  if(!reg)
    return NULL;

  /* Now lets see if fieldmeta has one */

  if(!fieldmeta->hooks)
    return NULL;

  U32 hooki;
  for(hooki = 0; hooki < av_count(fieldmeta->hooks); hooki++) {
    struct FieldHook *hook = (struct FieldHook *)AvARRAY(fieldmeta->hooks)[hooki];

    if(hook->funcs == reg->funcs)
      return hook;
  }

  return NULL;
}

AV *ClassPlain_mop_field_get_attribute_values(pTHX_ FieldMeta *fieldmeta, const char *name)
{
  COPHH *cophh = CopHINTHASH_get(PL_curcop);

  /* First, work out what hookfuncs the name maps to */

  FieldAttributeRegistration *reg;
  for(reg = fieldattrs; reg; reg = reg->next) {
    if(!strEQ(name, reg->name))
      continue;

    if(reg->funcs->permit_hintkey &&
        !cophh_fetch_pvn(cophh, reg->funcs->permit_hintkey, reg->permit_hintkeylen, 0, 0))
      continue;

    break;
  }

  if(!reg)
    return NULL;

  /* Now lets see if fieldmeta has one */

  if(!fieldmeta->hooks)
    return NULL;

  AV *ret = NULL;

  U32 hooki;
  for(hooki = 0; hooki < av_count(fieldmeta->hooks); hooki++) {
    struct FieldHook *hook = (struct FieldHook *)AvARRAY(fieldmeta->hooks)[hooki];

    if(hook->funcs != reg->funcs)
      continue;

    if(!ret)
      ret = newAV();

    av_push(ret, newSVsv(hook->hookdata));
  }

  return ret;
}

void ClassPlain_mop_field_seal(pTHX_ FieldMeta *fieldmeta)
{
  MOP_FIELD_RUN_HOOKS_NOARGS(fieldmeta, seal);
}

/*******************
 * Attribute hooks *
 *******************/

/* :reader */

static SV *make_accessor_mnamesv(pTHX_ FieldMeta *fieldmeta, SV *mname, const char *fmt)
{
  /* if(mname && !is_valid_ident_utf8((U8 *)mname))
    croak("Invalid accessor method name");
    */

  if(mname && SvPOK(mname))
    return SvREFCNT_inc(mname);

  const char *pv;
    pv = SvPVX(fieldmeta->name) + 1;

  mname = newSVpvf(fmt, pv);
  if(SvUTF8(fieldmeta->name))
    SvUTF8_on(mname);
  return mname;
}

static void S_generate_field_accessor_method(pTHX_ FieldMeta *fieldmeta, SV *mname, int type)
{
  ENTER;

  ClassMeta *classmeta = fieldmeta->class;

  SV *mname_fq = newSVpvf("%" SVf "::%" SVf, classmeta->name, mname);

  if(PL_curstash != classmeta->stash) {
    /* RT141599 */
    SAVESPTR(PL_curstash);
    PL_curstash = classmeta->stash;
  }

  need_PLparser();

  I32 floor_ix = start_subparse(FALSE, 0);
  SAVEFREESV(PL_compcv);

  I32 save_ix = block_start(TRUE);

  ClassPlain_extend_pad_vars(classmeta);

  struct AccessorGenerationCtx ctx = { 0 };

  ctx.padix = pad_add_name_sv(fieldmeta->name, 0, NULL, NULL);
  intro_my();

  OP *ops = op_append_list(OP_LINESEQ, NULL,
    newSTATEOP(0, NULL, NULL));
  ops = op_append_list(OP_LINESEQ, ops,
    ClassPlain_newMETHSTARTOP(0 |
      (0) |
      (classmeta->repr << 8)));

  int req_args = 0;
  int opt_args = 0;
  int slurpy_arg = 0;

  req_args = 1;

  ops = op_append_list(OP_LINESEQ, ops,
    make_argcheck_ops(req_args, opt_args, slurpy_arg, mname_fq));

  U32 flags = 0;

  flags = OPpFIELDPAD_SV << 8;

  ops = op_append_list(OP_LINESEQ, ops,
    ClassPlain_newFIELDPADOP(flags, ctx.padix, fieldmeta->fieldix));

  MOP_FIELD_RUN_HOOKS(fieldmeta, gen_accessor_ops, type, &ctx);

  if(ctx.bodyop)
    ops = op_append_list(OP_LINESEQ, ops, ctx.bodyop);

  if(ctx.post_bodyops)
    ops = op_append_list(OP_LINESEQ, ops, ctx.post_bodyops);

  if(!ctx.retop)
    croak("Require ctx.retop");
  ops = op_append_list(OP_LINESEQ, ops, ctx.retop);

  SvREFCNT_inc(PL_compcv);
  ops = block_end(save_ix, ops);

  CV *cv = newATTRSUB(floor_ix, newSVOP(OP_CONST, 0, mname_fq), NULL, NULL, ops);
  CvMETHOD_on(cv);

  ClassPlain_mop_class_add_method(classmeta, mname);

  LEAVE;
}

static bool fieldhook_reader_apply(pTHX_ FieldMeta *fieldmeta, SV *value, SV **hookdata_ptr, void *_funcdata)
{
  *hookdata_ptr = make_accessor_mnamesv(aTHX_ fieldmeta, value, "%s");
  return TRUE;
}

static void fieldhook_reader_seal(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *_funcdata)
{
  S_generate_field_accessor_method(aTHX_ fieldmeta, hookdata, ACCESSOR_READER);
}

static void fieldhook_gen_reader_ops(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *_funcdata, enum AccessorType type, struct AccessorGenerationCtx *ctx)
{
  if(type != ACCESSOR_READER)
    return;

  OPCODE optype = 0;

  optype = OP_PADSV;

  ctx->retop = newLISTOP(OP_RETURN, 0,
    newOP(OP_PUSHMARK, 0),
    newPADxVOP(optype, 0, ctx->padix));
}

static struct FieldHookFuncs fieldhooks_reader = {
  .ver              = OBJECTPAD_ABIVERSION,
  .apply            = &fieldhook_reader_apply,
  .seal             = &fieldhook_reader_seal,
  .gen_accessor_ops = &fieldhook_gen_reader_ops,
};

/* :writer */

static bool fieldhook_writer_apply(pTHX_ FieldMeta *fieldmeta, SV *value, SV **hookdata_ptr, void *_funcdata)
{
  *hookdata_ptr = make_accessor_mnamesv(aTHX_ fieldmeta, value, "set_%s");
  return TRUE;
}

static void fieldhook_writer_seal(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *_funcdata)
{
  S_generate_field_accessor_method(aTHX_ fieldmeta, hookdata, ACCESSOR_WRITER);
}

static void fieldhook_gen_writer_ops(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *_funcdata, enum AccessorType type, struct AccessorGenerationCtx *ctx)
{
  if(type != ACCESSOR_WRITER)
    return;

  ctx->bodyop = newBINOP(OP_SASSIGN, 0,
    newOP(OP_SHIFT, 0),
    newPADxVOP(OP_PADSV, 0, ctx->padix));

  ctx->retop = newLISTOP(OP_RETURN, 0,
    newOP(OP_PUSHMARK, 0),
    newPADxVOP(OP_PADSV, 0, PADIX_SELF));
}

static struct FieldHookFuncs fieldhooks_writer = {
  .ver              = OBJECTPAD_ABIVERSION,
  .apply            = &fieldhook_writer_apply,
  .seal             = &fieldhook_writer_seal,
  .gen_accessor_ops = &fieldhook_gen_writer_ops,
};

/* :accessor */

static bool fieldhook_accessor_apply(pTHX_ FieldMeta *fieldmeta, SV *value, SV **hookdata_ptr, void *_funcdata)
{
  *hookdata_ptr = make_accessor_mnamesv(aTHX_ fieldmeta, value, "%s");
  return TRUE;
}

/* :accessor */

static void fieldhook_accessor_seal(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *_funcdata)
{
  S_generate_field_accessor_method(aTHX_ fieldmeta, hookdata, ACCESSOR_COMBINED);
}

static void fieldhook_gen_accessor_ops(pTHX_ FieldMeta *fieldmeta, SV *hookdata, void *_funcdata, enum AccessorType type, struct AccessorGenerationCtx *ctx)
{
  if(type != ACCESSOR_COMBINED)
    return;

  /* $field = shift if @_ */
  ctx->bodyop = newLOGOP(OP_AND, 0,
    /* scalar @_ */
    op_contextualize(newUNOP(OP_RV2AV, 0, newGVOP(OP_GV, 0, PL_defgv)), G_SCALAR),
    /* $field = shift */
    newBINOP(OP_SASSIGN, 0,
      newOP(OP_SHIFT, 0),
      newPADxVOP(OP_PADSV, 0, ctx->padix)));

  ctx->retop = newLISTOP(OP_RETURN, 0,
    newOP(OP_PUSHMARK, 0),
    newPADxVOP(OP_PADSV, 0, ctx->padix));
}

static struct FieldHookFuncs fieldhooks_accessor = {
  .ver              = OBJECTPAD_ABIVERSION,
  .apply            = &fieldhook_accessor_apply,
  .seal             = &fieldhook_accessor_seal,
  .gen_accessor_ops = &fieldhook_gen_accessor_ops,
};

void ClassPlain__boot_fields(pTHX)
{
  ClassPlain_register_field_attribute("reader",   &fieldhooks_reader,   NULL);
  ClassPlain_register_field_attribute("writer",   &fieldhooks_writer,   NULL);
  ClassPlain_register_field_attribute("accessor", &fieldhooks_accessor, NULL);
}
