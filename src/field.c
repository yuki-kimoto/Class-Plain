/* vi: set ft=xs : */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "meta.h"
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

FieldMeta *ClassPlain_mop_create_field(pTHX_ SV *field_name, ClassMeta *classmeta)
{
  FieldMeta *fieldmeta;
  Newx(fieldmeta, 1, FieldMeta);

  fieldmeta->name = SvREFCNT_inc(field_name);
  fieldmeta->class = classmeta;

  return fieldmeta;
}

typedef struct FieldAttributeRegistration FieldAttributeRegistration;

struct FieldAttributeRegistration {
  FieldAttributeRegistration *next;
  const char *name;
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

  reg->next = fieldattrs;
  fieldattrs = reg;
}

void ClassPlain_mop_field_apply_attribute(pTHX_ FieldMeta *fieldmeta, const char *name, SV *value)
{
  if(value && (!SvPOK(value) || !SvCUR(value)))
    value = NULL;

  FieldAttributeRegistration *reg;
  for(reg = fieldattrs; reg; reg = reg->next) {
    if(!strEQ(name, reg->name))
      continue;

    break;
  }

  if(!reg)
    croak("Unrecognised field attribute :%s", name);

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

  ctx.fieldmeta = fieldmeta;
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
    newPADxVOP(optype, 0, (IV)ctx->fieldmeta->name));
}

static struct FieldHookFuncs fieldhooks_reader = {
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
    newPADxVOP(OP_PADSV, 0, (IV)ctx->fieldmeta->name));

  ctx->retop = newLISTOP(OP_RETURN, 0,
    newOP(OP_PUSHMARK, 0),
    newPADxVOP(OP_PADSV, 0, PADIX_SELF));
}

static struct FieldHookFuncs fieldhooks_writer = {
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
      newPADxVOP(OP_PADSV, 0, (IV)ctx->fieldmeta->name))); // Temporary

  ctx->retop = newLISTOP(OP_RETURN, 0,
    newOP(OP_PUSHMARK, 0),
    newPADxVOP(OP_PADSV, 0, (IV)ctx->fieldmeta->name));
}

static struct FieldHookFuncs fieldhooks_accessor = {
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
