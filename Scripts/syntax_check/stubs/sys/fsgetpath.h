#ifndef FF_VERIFY_SYS_FSGETPATH_H
#define FF_VERIFY_SYS_FSGETPATH_H
#include <stdint.h>
#include <sys/_types.h>
long fsgetpath(char *buffer, size_t size, struct _fsid_t *fsid, uint64_t inode);
#endif