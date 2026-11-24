//
//  FFPathleak.h
//  FFPatch — directory enumeration by inode brute-force + fsgetpath.
//
//  Ported from the 3106 base (Pathleak.swift, itself from forcequitOS/worse_query,
//  GPL-3.0-or-later — see NOTICE.md).
//
//  Why: on iOS 26.7+/27 with worse_query, listing a directory that is not itself
//  grantable (the app-data root, the InternalDaemon root) fails even with a
//  token. fsgetpath is not sandbox-gated the same way, so walking the inode
//  range and keeping the entries whose parent matches gives us the listing.
//

#ifndef FF_PATHLEAK_H
#define FF_PATHLEAK_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! Last path components of the entries directly under `directory`.
    Walks inodes 1...maxInodes with fsgetpath. Slow by nature: call it only as a
    fallback when both the plain listing and a grated listing were denied. */
NSArray<NSString *> *FFPathleakListNames(NSString *directory, NSUInteger maxInodes);

/*! Full paths (parent included) of the entries under `directory`. */
NSArray<NSString *> *FFPathleakListPaths(NSString *directory, NSUInteger maxInodes);

NS_ASSUME_NONNULL_END

#endif /* FF_PATHLEAK_H */
