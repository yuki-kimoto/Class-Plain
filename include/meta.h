#ifndef __CLASS_PLAIN__TYPES_H__
#define __CLASS_PLAIN__TYPES_H__

#define CLASSPLAIN_ABIVERSION_MINOR 57
#define CLASSPLAIN_ABIVERSION_MAJOR 0

#define CLASSPLAIN_ABIVERSION  ((CLASSPLAIN_ABIVERSION_MAJOR << 16) | (CLASSPLAIN_ABIVERSION_MINOR))

typedef struct MethodMeta MethodMeta;

/* Function prototypes */

OP *ClassPlain_newMETHSTARTOP(pTHX_ U32 flags);

OP *ClassPlain_newCOMMONMETHSTARTOP(pTHX_ U32 flags);

#endif
