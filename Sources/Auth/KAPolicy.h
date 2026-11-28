#ifndef KA_POLICY_H
#define KA_POLICY_H
/* Implemented as virtualized bytecode in release builds. Server proof remains mandatory. */
int KAPolicyAccept(unsigned long long flags, unsigned long long expiry,
                   unsigned long long now, unsigned long long deadline,
                   unsigned long long uptime);
#endif
