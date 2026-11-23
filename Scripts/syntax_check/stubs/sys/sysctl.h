#ifndef FF_VERIFY_SYS_SYSCTL_H
#define FF_VERIFY_SYS_SYSCTL_H
#include <stddef.h>
#define CTL_KERN 1
#define KERN_PROC 14
#define KERN_PROC_PID 1
int sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int sysctl(int *name, unsigned int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
#endif