#include "KAPolicy.h"
__attribute__((noinline, visibility("hidden")))
int KAPolicyAccept(unsigned long long flags, unsigned long long expiry,
                   unsigned long long now, unsigned long long deadline,
                   unsigned long long uptime) {
    if (flags != 15) return 0;
    if (now == 0 || uptime == 0) return 0;
    if (expiry <= now || deadline <= uptime) return 0;
    /* A grant/session can never extend its monotonic lease beyond five minutes. */
    if (deadline - uptime > 300000) return 0;
    return 1;
}
