#ifndef FF_VERIFY_SYS_STAT_H
#define FF_VERIFY_SYS_STAT_H
#include <stdint.h>
typedef unsigned short mode_t;
typedef unsigned long off_t;
struct stat {
    mode_t st_mode;
    uint64_t st_ino;
    uint64_t st_dev;
    uint64_t st_size;
    uint32_t st_uid;
    uint32_t st_gid;
};
#define S_IFMT 0170000
#define S_IFDIR 0040000
#define S_IFREG 0100000
#define S_IFLNK 0120000
#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
int stat(const char *path, struct stat *info);
int lstat(const char *path, struct stat *info);
int fstat(int descriptor, struct stat *info);
int chmod(const char *path, mode_t mode);
int fchmod(int descriptor, mode_t mode);
int mkdir(const char *path, mode_t mode);
#endif