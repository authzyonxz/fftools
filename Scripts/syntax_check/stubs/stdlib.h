#ifndef FF_VERIFY_STDLIB_H
#define FF_VERIFY_STDLIB_H
#include <stddef.h>
void *malloc(size_t size);
void *calloc(size_t count, size_t size);
void *realloc(void *pointer, size_t size);
void free(void *pointer);
void exit(int status);
int atoi(const char *string);
long strtol(const char *string, char **end, int base);
char *getenv(const char *name);
#endif