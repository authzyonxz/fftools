#ifndef FF_VERIFY_SYS_PROC_H
#define FF_VERIFY_SYS_PROC_H
#include <stdint.h>
struct extern_proc {
    int p_flag;
};
struct proc {
    struct extern_proc p_flag_placeholder;
    struct extern_proc p_stats;
};
struct kinfo_proc {
    struct {
        struct {
            int p_flag;
        } p_flag_container;
    } kp_proc_placeholder;
    struct {
        int p_flag;
    } kp_proc;
};
#define P_TRACED 0x00000800
#endif