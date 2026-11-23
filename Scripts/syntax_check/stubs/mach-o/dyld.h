#ifndef FF_VERIFY_DYLD_H
#define FF_VERIFY_DYLD_H
#include <stdint.h>
int _NSGetExecutablePath(char *buffer, uint32_t *size);
#endif