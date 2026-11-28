#ifndef KA_POLICY_H
#define KA_POLICY_H

int KAPolicyAccept(unsigned long long flags, unsigned long long expiry,
                   unsigned long long now, unsigned long long deadline,
                   unsigned long long uptime);
#endif
