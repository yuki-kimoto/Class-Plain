#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "XSParseKeyword.h"

#include "XSParseSublike.h"

#include "perl-backcompat.c.inc"
#include "sv_setrv.c.inc"

#include "perl-additions.c.inc"
#include "lexer-additions.c.inc"
#include "forbid_outofblock_ops.c.inc"
#include "force_list_keeping_pushmark.c.inc"
#include "optree-additions.c.inc"
#include "newOP_CUSTOM.c.inc"

#include "class_plain_parser.h"
#include "class_plain_class.h"
#include "class_plain_field.h"
#include "class_plain_method.h"

/**********************************
 * Class and Field Implementation *
 **********************************/

#define METATYPE_ROLE 1

static XOP xop_methstart;
static OP* pp_methstart(pTHX) {
  SV* self = av_shift(GvAV(PL_defgv));

  if(!SvROK(self) || !SvOBJECT(SvRV(self)))
    croak("Cannot invoke method on a non-instance");

  save_clearsv(&PAD_SVl(1));
  sv_setsv(PAD_SVl(1), self);

  return PL_op->op_next;
}

OP* ClassPlain_newMETHSTARTOP(pTHX_ U32 flags)
{
  OP* op = newOP_CUSTOM(&pp_methstart, flags);
  op->op_private = (U8)(flags >> 8);
  return op;
}

static XOP xop_commonmethstart;
static OP* pp_commonmethstart(pTHX) {
  SV* self = av_shift(GvAV(PL_defgv));

  if(SvROK(self))
    /* TODO: Should handle this somehow */
    croak("Cannot invoke common method on an instance");

  save_clearsv(&PAD_SVl(1));
  sv_setsv(PAD_SVl(1), self);

  return PL_op->op_next;
}

OP* ClassPlain_newCOMMONMETHSTARTOP(pTHX_ U32 flags) {
  OP* op = newOP_CUSTOM(&pp_commonmethstart, flags);
  op->op_private = (U8)(flags >> 8);
  return op;
}

/* The classdata on the currently-compiling class */
#define compclass_class       S_compclass_class(aTHX)
static ClassMeta *S_compclass_class(pTHX) {
  SV** svp = hv_fetchs(GvHV(PL_hintgv), "Class::Plain/compclass_class", 0);
  if(!svp || !*svp || !SvOK(*svp))
    return NULL;
  return (ClassMeta *)(intptr_t)SvIV(*svp);
}

#define have_compclass_class  S_have_compclass_class(aTHX)
static bool S_have_compclass_class(pTHX) {
  SV** svp = hv_fetchs(GvHV(PL_hintgv), "Class::Plain/compclass_class", 0);
  if(!svp || !*svp)
    return false;

  if(SvOK(*svp) && SvIV(*svp))
    return true;

  return false;
}

#define compclass_class_set(class)  S_compclass_class_set(aTHX_ class)
static void S_compclass_class_set(pTHX_ ClassMeta *class) {
  SV* sv = *hv_fetchs(GvHV(PL_hintgv), "Class::Plain/compclass_class", GV_ADD);
  sv_setiv(sv, (IV)(intptr_t)class);
}

#define is_valid_ident_utf8(s)  S_is_valid_ident_utf8(aTHX_ s)
static bool S_is_valid_ident_utf8(pTHX_ const U8* s) {
  const U8* e = s + strlen((char *)s);

  if(!isIDFIRST_utf8_safe(s, e))
    return false;

  s += UTF8SKIP(s);
  while(*s) {
    if(!isIDCONT_utf8_safe(s, e))
      return false;
    s += UTF8SKIP(s);
  }

  return true;
}

static void inplace_trim_whitespace(SV* sv)
{
  if(!SvPOK(sv) || !SvCUR(sv))
    return;

  char *dst = SvPVX(sv);
  char *src = dst;

  while(*src && isSPACE(*src))
    src++;

  if(src > dst) {
    size_t offset = src - dst;
    Move(src, dst, SvCUR(sv) - offset, char);
    SvCUR(sv) -= offset;
  }

  src = dst + SvCUR(sv) - 1;
  while(src > dst && isSPACE(*src))
    src--;

  SvCUR(sv) = src - dst + 1;
  dst[SvCUR(sv)] = 0;
}

static void S_apply_method_common(pTHX_ MethodMeta* class, const char *val, void* _data) {
  class->is_common = true;
}

static struct MethodAttributeDefinition method_attributes[] = {
  { "common",   &S_apply_method_common,   0 },
  { 0 }
};

/*******************
 * Custom Keywords *
 *******************/

static int build_classlike(pTHX_ OP* *out, XSParseKeywordPiece* args[], size_t nargs, void* hookdata) {
  int argi = 0;
  

  SV* packagename = args[argi++]->sv;
  /* Grrr; XPK bug */
  if(!packagename)
    croak("Expected a class name after 'class'");

  IV type = (IV)(intptr_t)hookdata;
  
  ClassMeta* class_class = ClassPlain_create_class(aTHX_ type, packagename);
  
  if (type == 1) {
    class_class->is_role = 1;
  }

  int nattrs = args[argi++]->i;
  if(nattrs) {
    int i;
    for(i = 0; i < nattrs; i++) {
      SV* attrname = args[argi]->attr.name;
      SV* attrval  = args[argi]->attr.value;

      inplace_trim_whitespace(attrval);

      ClassPlain_class_apply_attribute(aTHX_ class_class, SvPVX(attrname), attrval);

      argi++;
    }
  }

  ClassPlain_begin_class_block(aTHX_ class_class);

  /* At this point XS::Parse::Keyword has parsed all it can. From here we will
   * take over to perform the odd "block or statement" behaviour of `class`
   * keywords
   */

  bool exists_class_block;

  if(lex_consume_unichar('{')) {
    exists_class_block = true;
    ENTER;
  }
  else if(lex_consume_unichar(';')) {
    exists_class_block = false;
  }
  else
    croak("Expected a block or ';'");

  /* CARGOCULT from perl/op.c:Perl_package() */
  {
    SAVEGENERICSV(PL_curstash);
    save_item(PL_curstname);

    PL_curstash = (HV *)SvREFCNT_inc(gv_stashsv(class_class->name, GV_ADD));
    sv_setsv(PL_curstname, packagename);

    PL_hints |= HINT_BLOCK_SCOPE;
    PL_parser->copline = NOLINE;
  }

  if (exists_class_block) {
    I32 save_ix = block_start(TRUE);
    compclass_class_set(class_class);

    OP* body = parse_stmtseq(0);
    body = block_end(save_ix, body);

    if(!lex_consume_unichar('}'))
      croak("Expected }");
    
    // the end of the class block
    
    LEAVE;

    /* CARGOCULT from perl/perly.y:PACKAGE BAREWORD BAREWORD '{' */
    /* a block is a loop that happens once */
    *out = op_append_elem(OP_LINESEQ,
      newWHILEOP(0, 1, NULL, NULL, body, NULL, 0),
      newSVOP(OP_CONST, 0, &PL_sv_yes));
    return KEYWORD_PLUGIN_STMT;
  }
  else {
    SAVEHINTS();
    compclass_class_set(class_class);

    *out = newSVOP(OP_CONST, 0, &PL_sv_yes);
    return KEYWORD_PLUGIN_STMT;
  }
}

static const struct XSParseKeywordPieceType pieces_classlike[] = {
  XPK_PACKAGENAME,
  /* This should really a repeated (tagged?) choice of a number of things, but
   * right now there's only one thing permitted here anyway
   */
  XPK_ATTRIBUTES,
  {0}
};

static const struct XSParseKeywordHooks kwhooks_class = {
  .permit_hintkey = "Class::Plain/class",
  .pieces = pieces_classlike,
  .build = &build_classlike,
};

static void check_field(pTHX_ void* hookdata) {
  char *kwname = hookdata;
  
  if(!have_compclass_class)
    croak("Cannot '%s' outside of 'class'", kwname);

  if(!sv_eq(PL_curstname, compclass_class->name))
    croak("Current package name no longer matches current class (%" SVf " vs %" SVf ")",
      PL_curstname, compclass_class->name);
}

static int build_field(pTHX_ OP* *out, XSParseKeywordPiece* args[], size_t nargs, void* hookdata) {
  int argi = 0;

  SV* name = args[argi++]->sv;

  FieldMeta *field_class = ClassPlain_class_add_field(aTHX_ compclass_class, name);
  SvREFCNT_dec(name);

  int nattrs = args[argi++]->i;
  if(nattrs) {
    while(argi < (nattrs+2)) {
      SV* attrname = args[argi]->attr.name;
      SV* attrval  = args[argi]->attr.value;

      inplace_trim_whitespace(attrval);

      ClassPlain_field_apply_attribute(aTHX_ field_class, SvPVX(attrname), attrval);

      if(attrval)
        SvREFCNT_dec(attrval);

      argi++;
    }
  }

  return KEYWORD_PLUGIN_STMT;
}

static const struct XSParseKeywordHooks kwhooks_field = {
  .flags = XPK_FLAG_STMT,

  .check = &check_field,

  .permit_hintkey = "Class::Plain/field",
  .pieces = (const struct XSParseKeywordPieceType []){
    XPK_IDENT,
    XPK_ATTRIBUTES,
    {0}
  },
  .build = &build_field,
};
static bool parse_method_permit(pTHX_ void* hookdata)
{
  if(!have_compclass_class)
    croak("Cannot 'method' outside of 'class'");

  if(!sv_eq(PL_curstname, compclass_class->name))
    croak("Current package name no longer matches current class (%" SVf " vs %" SVf ")",
      PL_curstname, compclass_class->name);

  return true;
}

static void parse_method_pre_subparse(pTHX_ struct XSParseSublikeContext* ctx, void* hookdata) {
  /* While creating the new scope CV we need to ENTER a block so as not to
   * break any interpvars
   */
  ENTER;
  SAVESPTR(PL_comppad);
  SAVESPTR(PL_comppad_name);
  SAVESPTR(PL_curpad);

  intro_my();

  MethodMeta* compmethodclass;
  Newx(compmethodclass, 1, MethodMeta);

  compmethodclass->name = SvREFCNT_inc(ctx->name);
  compmethodclass->class = NULL;
  compmethodclass->is_common = false;

  hv_stores(ctx->moddata, "Class::Plain/compmethodclass", newSVuv(PTR2UV(compmethodclass)));
  
  LEAVE;
}

static bool parse_method_filter_attr(pTHX_ struct XSParseSublikeContext* ctx, SV* attr, SV* val, void* hookdata) {
  MethodMeta* compmethodclass = NUM2PTR(MethodMeta* , SvUV(*hv_fetchs(ctx->moddata, "Class::Plain/compmethodclass", 0)));

  struct MethodAttributeDefinition *def;
  for(def = method_attributes; def->attrname; def++) {
    if(!strEQ(SvPVX(attr), def->attrname))
      continue;

    /* TODO: We might want to wrap the CV in some sort of MethodMeta struct
     * but for now we'll just pass the XSParseSublikeContext context */
    (*def->apply)(aTHX_ compmethodclass, SvPOK(val) ? SvPVX(val) : NULL, def->applydata);

    return true;
  }

  /* No error, just let it fall back to usual attribute handling */
  return false;
}

static void parse_method_post_blockstart(pTHX_ struct XSParseSublikeContext* ctx, void* hookdata) {
  MethodMeta* compmethodclass = NUM2PTR(MethodMeta* , SvUV(*hv_fetchs(ctx->moddata, "Class::Plain/compmethodclass", 0)));
  if(compmethodclass->is_common) {
    IV var_index = pad_add_name_pvs("$class", 0, NULL, NULL);
    if (!(var_index == 1)) {
      croak("[Unexpected]Invalid index of the $class variable:%d", (int)var_index);
    }
  }
  else {
    IV var_index = pad_add_name_pvs("$self", 0, NULL, NULL);
    if(var_index != 1) {
      croak("[Unexpected]Invalid index of the $self variable:%d", (int)var_index);
    }
  }

  intro_my();
}

static void parse_method_pre_blockend(pTHX_ struct XSParseSublikeContext* ctx, void* hookdata) {
  MethodMeta* compmethodclass = NUM2PTR(MethodMeta* , SvUV(*hv_fetchs(ctx->moddata, "Class::Plain/compmethodclass", 0)));

  /* If we have no ctx->body that means this was a bodyless method
   * declaration; a required method
   */
  if (ctx->body) {
    if(compmethodclass->is_common) {
      ctx->body = op_append_list(OP_LINESEQ,
        ClassPlain_newCOMMONMETHSTARTOP(aTHX_ 0 |
          (0)),
        ctx->body);
    }
    else {
      OP* fieldops = NULL, *methstartop;
      fieldops = op_append_list(OP_LINESEQ, fieldops,
        newSTATEOP(0, NULL, NULL));
      fieldops = op_append_list(OP_LINESEQ, fieldops,
        (methstartop = ClassPlain_newMETHSTARTOP(aTHX_ 0 |
          (0) |
          (0))));

      ctx->body = op_append_list(OP_LINESEQ, fieldops, ctx->body);
    }
  }
}

static void parse_method_post_newcv(pTHX_ struct XSParseSublikeContext* ctx, void* hookdata) {
  MethodMeta* compmethodclass;
  {
    SV* tmpsv = *hv_fetchs(ctx->moddata, "Class::Plain/compmethodclass", 0);
    compmethodclass = NUM2PTR(MethodMeta* , SvUV(tmpsv));
    sv_setuv(tmpsv, 0);
  }

  if(ctx->cv)
    CvMETHOD_on(ctx->cv);

    if(ctx->cv && ctx->name && (ctx->actions & XS_PARSE_SUBLIKE_ACTION_INSTALL_SYMBOL)) {
      MethodMeta* method_class = ClassPlain_class_add_method(aTHX_ compclass_class, ctx->name);

      method_class->is_common = compmethodclass->is_common;
    }

  SvREFCNT_dec(compmethodclass->name);
  Safefree(compmethodclass);
}

static struct XSParseSublikeHooks parse_method_hooks = {
  .flags           = XS_PARSE_SUBLIKE_FLAG_FILTERATTRS |
                     XS_PARSE_SUBLIKE_COMPAT_FLAG_DYNAMIC_ACTIONS |
                     XS_PARSE_SUBLIKE_FLAG_BODY_OPTIONAL,
  .permit_hintkey  = "Class::Plain/method",
  .permit          = parse_method_permit,
  .pre_subparse    = parse_method_pre_subparse,
  .filter_attr     = parse_method_filter_attr,
  .post_blockstart = parse_method_post_blockstart,
  .pre_blockend    = parse_method_pre_blockend,
  .post_newcv      = parse_method_post_newcv,
};

/* internal function shared by various *.c files */
void ClassPlain_need_PLparser(pTHX)
{
  if(!PL_parser) {
    /* We need to generate just enough of a PL_parser to keep newSTATEOP()
     * happy, otherwise it will SIGSEGV (RT133258)
     */
    SAVEVPTR(PL_parser);
    Newxz(PL_parser, 1, yy_parser);
    SAVEFREEPV(PL_parser);

    PL_parser->copline = NOLINE;
  }
}

MODULE = Class::Plain    PACKAGE = Class::Plain::MetaFunctions

BOOT:
  XopENTRY_set(&xop_methstart, xop_name, "methstart");
  XopENTRY_set(&xop_methstart, xop_desc, "enter method");
  XopENTRY_set(&xop_methstart, xop_class, OA_BASEOP);
  Perl_custom_op_register(aTHX_ &pp_methstart, &xop_methstart);

  XopENTRY_set(&xop_commonmethstart, xop_name, "commonmethstart");
  XopENTRY_set(&xop_commonmethstart, xop_desc, "enter method :common");
  XopENTRY_set(&xop_commonmethstart, xop_class, OA_BASEOP);
  Perl_custom_op_register(aTHX_ &pp_commonmethstart, &xop_commonmethstart);

  boot_xs_parse_keyword(0.22); /* XPK_AUTOSEMI */
  
  register_xs_parse_keyword("class", &kwhooks_class, (void*)0);
  register_xs_parse_keyword("role",  &kwhooks_class,  (void*)METATYPE_ROLE);

  register_xs_parse_keyword("field", &kwhooks_field, "field");
  
  boot_xs_parse_sublike(0.15); /* dynamic actions */

  register_xs_parse_sublike("method", &parse_method_hooks, (void*)0);
