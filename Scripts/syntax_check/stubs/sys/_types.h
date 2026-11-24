#ifndef FF_VERIFY_SYS_TYPES_INTERNAL_H
#define FF_VERIFY_SYS_TYPES_INTERNAL_H
#include <stdint.h>
struct _fsid_t { int32_t val[2]; };
typedef struct _fsid_t fsid_t;
#endif