

#ifndef FF_PATHLEAK_H
#define FF_PATHLEAK_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSArray<NSString *> *FFPathleakListNames(NSString *directory, NSUInteger maxInodes);

NSArray<NSString *> *FFPathleakListPaths(NSString *directory, NSUInteger maxInodes);

NS_ASSUME_NONNULL_END

#endif
