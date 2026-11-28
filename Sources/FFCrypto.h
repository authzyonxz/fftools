

#ifndef FF_CRYPTO_H
#define FF_CRYPTO_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSData *_Nullable FFDecryptPack(NSData *pack,
                                NSString *functionID,
                                NSString *gameID,
                                NSError *_Nullable *_Nullable error);

NSString *FFSHA256HexOfData(NSData *data);

NS_ASSUME_NONNULL_END

#endif
