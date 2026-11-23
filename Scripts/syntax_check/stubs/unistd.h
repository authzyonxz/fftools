#ifndef FF_VERIFY_UNISTD_H
#define FF_VERIFY_UNISTD_H
#include <stddef.h>
typedef long ssize_t;
typedef int pid_t;
int close(int descriptor);
int fsync(int descriptor);
int unlink(const char *path);
int rmdir(const char *path);
int getpid(void);
unsigned int sleep(unsigned int seconds);
int usleep(unsigned int microseconds);
long sysconf(int name);
#endif