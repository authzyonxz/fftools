#ifndef FF_VERIFY_COMMON_CRYPTOR_H
#define FF_VERIFY_COMMON_CRYPTOR_H
#include <stdint.h>
#include <stddef.h>
typedef int32_t CCCryptorStatus;
#define kCCSuccess 0
#define kCCBlockSizeAES128 16
typedef uint32_t CCOperation;
#define kCCDecrypt 0
#define kCCEncrypt 1
typedef uint32_t CCAlgorithm;
#define kCCAlgorithmAES 0
typedef uint32_t CCOptions;
#define kCCOptionPKCS7Padding 1
CCCryptorStatus CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions options,
                        const void *key, size_t keyLength, const void *iv,
                        const void *dataIn, size_t dataInLength,
                        void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);
#endif