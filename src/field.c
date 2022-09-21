/* vi: set ft=xs : */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "class_plain_parser.h"
#include "class_plain_class.h"
#include "class_plain_field.h"

#include "perl-backcompat.c.inc"
#include "optree-additions.c.inc"
#include "make_argcheck_ops.c.inc"

void ClassPlain_need_PLparser(pTHX);

FieldMeta *ClassPlain_mop_create_field(pTHX_ SV *field_name, ClassMeta *classmeta)
{
  FieldMeta *fieldmeta;
  Newx(fieldmeta, 1, FieldMeta);

  fieldmeta->name = SvREFCNT_inc(field_name);
  fieldmeta->class = classmeta;
  fieldmeta->hooks = NULL;

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

  if(!fieldmeta->hooks) {
    fieldmeta->hooks = newAV();
  }
  
  struct FieldHook *hook;
  Newx(hook, 1, struct FieldHook);

  hook->funcs = reg->funcs;
  hook->hookdata = hookdata;
  hook->funcdata = reg->funcdata;

  av_push(fieldmeta->hooks, (SV *)hook);
}

void ClassPlain_mop_field_seal(pTHX_ FieldMeta *fieldmeta)
{
  // Run hooks
  {                                                                                       
    U32 hooki;                                                                            
    for(hooki = 0; fieldmeta->hooks && hooki < av_count(fieldmeta->hooks); hooki++) {     
      struct FieldHook *h = (struct FieldHook *)AvARRAY(fieldmeta->hooks)[hooki];         
      if(*h->funcs->seal)                                                                 
        (*h->funcs->seal)(aTHX_ fieldmeta, h->hookdata, h->funcdata);        
    }                                                                                     
  }
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

  ClassPlain_need_PLparser();

  I32 floor_ix = start_subparse(FALSE, 0);
  SAVEFREESV(PL_compcv);

  I32 save_ix = block_start(TRUE);

  struct AccessorGenerationCtx ctx = { 0 };

  ctx.fieldmeta = fieldmeta;
  intro_my();

  OP *ops = op_append_list(OP_LINESEQ, NULL,
    newSTATEOP(0, NULL, NULL));
  ops = op_append_list(OP_LINESEQ, ops,
    ClassPlain_newMETHSTARTOP(0 |
      (0) |
      (0)));

  int req_args = 0;
  int opt_args = 0;
  int slurpy_arg = 0;

  req_args = 1;

  ops = op_append_list(OP_LINESEQ, ops,
    make_argcheck_ops(req_args, opt_args, slurpy_arg, mname_fq));
  
  // Run hooks
  {                                                                                       
    U32 hooki;                                                                            
    for(hooki = 0; fieldmeta->hooks && hooki < av_count(fieldmeta->hooks); hooki++) {     
      struct FieldHook *h = (struct FieldHook *)AvARRAY(fieldmeta->hooks)[hooki];         
      if(*h->funcs->gen_accessor_ops)                                                                 
        (*h->funcs->gen_accessor_ops)(aTHX_ fieldmeta, h->hookdata, h->funcdata, type, &ctx);        
    }                                                                                     
  }


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
    newBINOP(
      OP_HELEM,
      0,
      doref(newPADxVOP(optype, 0, 1), OP_RV2HV, 1),
      newSVOP(OP_CONST, 0, ctx->fieldmeta->name)
    )
  );
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
    newPADxVOP(OP_PADSV, 0, 1));
}

static struct FieldHookFuncs fieldhooks_writer = {
  .apply            = &fieldhook_writer_apply,
  .seal             = &fieldhook_writer_seal,
  .gen_accessor_ops = &fieldhook_gen_writer_ops,
};

void ClassPlain__boot_fields(pTHX)
{
  ClassPlain_register_field_attribute("reader",   &fieldhooks_reader,   NULL);
  ClassPlain_register_field_attribute("writer",   &fieldhooks_writer,   NULL);
}
