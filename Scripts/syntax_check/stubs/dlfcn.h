#ifndef FF_VERIFY_DLFCN_H
#define FF_VERIFY_DLFCN_H
#define RTLD_LAZY 1
#define RTLD_NOW 2
#define RTLD_LOCAL 4
#define RTLD_GLOBAL 8
#define RTLD_DEFAULT ((void *)0)
void *dlopen(const char *path, int mode);
void *dlsym(void *handle, const char *symbol);
int dlclose(void *handle);
char *dlerror(void);
#endif