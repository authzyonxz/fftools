#ifndef FF_VERIFY_COMMON_DIGEST_H
#define FF_VERIFY_COMMON_DIGEST_H
#include <stdint.h>
#include <stddef.h>
#define CC_SHA256_DIGEST_LENGTH 32
typedef uint32_t CC_LONG;
typedef struct { uint32_t state[8]; uint64_t bitcount; uint8_t buffer[64]; } CC_SHA256_CTX;
int CC_SHA256_Init(CC_SHA256_CTX *context);
int CC_SHA256_Update(CC_SHA256_CTX *context, const void *data, uint32_t length);
int CC_SHA256_Final(unsigned char *digest, CC_SHA256_CTX *context);
unsigned char *CC_SHA256(const void *data, uint32_t length, unsigned char *digest);
#endif