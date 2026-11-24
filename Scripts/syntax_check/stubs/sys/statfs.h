#ifndef FF_VERIFY_SYS_STATFS_H
#define FF_VERIFY_SYS_STATFS_H
#include <sys/_types.h>
struct statfs {
    int f_bsize;
    fsid_t f_fsid;
    long f_files;
};
int statfs(const char *path, struct statfs *info);
#endif