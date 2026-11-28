

#ifndef FF_PROTECT_H
#define FF_PROTECT_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *_Nullable FFMaskedString(const unsigned char *bytes, size_t length);

NSData *_Nullable FFMaskedData(const unsigned char *bytes, size_t length);

NSString *_Nullable FFCatalogBaseURL(void);

NSData *_Nullable FFMasterSecret(void);

void FFProtectInstall(void);

BOOL FFIsBeingTraced(void);

NS_ASSUME_NONNULL_END

#endif
