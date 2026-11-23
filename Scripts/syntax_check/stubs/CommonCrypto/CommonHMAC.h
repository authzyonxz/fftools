#ifndef FF_VERIFY_COMMON_HMAC_H
#define FF_VERIFY_COMMON_HMAC_H
#include <stdint.h>
#include <stddef.h>
typedef uint32_t CCHmacAlgorithm;
#define kCCHmacAlgSHA256 2
void CCHmac(CCHmacAlgorithm algorithm, const void *key, size_t keyLength,
            const void *data, size_t dataLength, void *macOut);
#endif