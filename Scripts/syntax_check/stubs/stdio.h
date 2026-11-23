#ifndef FF_VERIFY_STDIO_H
#define FF_VERIFY_STDIO_H
#include <stdarg.h>
#include <stddef.h>
typedef struct _FF_FILE FILE;
extern FILE *stderr;
int printf(const char *format, ...);
int fprintf(FILE *stream, const char *format, ...);
int snprintf(char *buffer, size_t size, const char *format, ...);
int sprintf(char *buffer, const char *format, ...);
void perror(const char *message);
#endif