/* Verification-only Foundation stub.
 *
 * Not part of the app. Exists so the Objective-C sources can be run through
 * `clang -fsyntax-only` on a machine without the iOS SDK. Declares the classes,
 * typedefs and globals the code mentions; method declarations are intentionally
 * sparse because missing selectors are warnings, not errors.
 */
#ifndef FF_VERIFY_FOUNDATION_H
#define FF_VERIFY_FOUNDATION_H

#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdbool.h>
#include <string.h>

typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO  ((BOOL)0)
#define nil ((id)0)

typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef double CGFloat;

#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define FOUNDATION_EXPORT extern
#define NS_SWIFT_NAME(x)
#define __unused __attribute__((unused))
#define NS_FORMAT_FUNCTION(a, b) __attribute__((format(__NSString__, a, b)))
#define NS_DESIGNATED_INITIALIZER
#define NS_UNAVAILABLE
#define NS_REQUIRES_SUPER
#define API_AVAILABLE(...)
#define API_DEPRECATED(...)
#define NS_ROOT_CLASS
#define typeof __typeof__
#define instancetype id

typedef struct CGPoint { CGFloat x; CGFloat y; } CGPoint;
typedef struct CGSize { CGFloat width; CGFloat height; } CGSize;
typedef struct CGRect { CGPoint origin; CGSize size; } CGRect;
typedef struct CGAffineTransform { CGFloat a, b, c, d, tx, ty; } CGAffineTransform;

typedef NS_ENUM(NSInteger, NSComparisonResult) {
    NSOrderedAscending = -1, NSOrderedSame = 0, NSOrderedDescending = 1
};
typedef double NSTimeInterval;

@class NSString, NSArray, NSDictionary, NSData, NSDate, NSError, NSURL, NSUUID,
       NSNumber, NSLock, NSSet, NSMutableArray, NSMutableDictionary,
       NSMutableSet, NSMutableString, NSFileManager, NSFileHandle, NSBundle,
       NSProcessInfo, NSUserDefaults, NSNotification, NSPropertyListSerialization,
       NSJSONSerialization, NSAttributedString, NSDateFormatter,
       NSISO8601DateFormatter, NSOperationQueue, NSThread, NSValue, NSCoder,
       NSException, NSCharacterSet, NSIndexSet, NSTimeZone, NSLocale,
       NSEnumerator, NSLayoutConstraint;

@protocol NSObject
@end
@protocol NSCopying
@end
@protocol NSFastEnumeration
@end

@interface NSObject <NSObject>
+ (instancetype)alloc;
+ (instancetype)new;
- (instancetype)init;
+ (Class)class;
- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;
- (BOOL)respondsToSelector:(SEL)selector;
- (BOOL)isKindOfClass:(Class)cls;
- (BOOL)isMemberOfClass:(Class)cls;
- (id)copy;
- (id)mutableCopy;
- (id)copy;
- (id)mutableCopy;
- (id)performSelector:(SEL)selector;
- (id)performSelector:(SEL)selector withObject:(id)object;
- (NSString *)description;
@end

@interface NSString : NSObject <NSCopying>
@property (readonly) NSUInteger length;
@property (readonly) const char *UTF8String;
@property (readonly) const char *fileSystemRepresentation;
@property (readonly) BOOL isAbsolutePath;
@property (readonly) NSString *lastPathComponent;
@property (readonly) NSString *pathExtension;
@property (readonly) NSArray *pathComponents;
@property (readonly) NSString *stringByDeletingLastPathComponent;
@property (readonly) NSString *stringByDeletingPathExtension;
@property (readonly) NSString *stringByResolvingSymlinksInPath;
@property (readonly) NSString *uppercaseString;
@property (readonly) NSString *lowercaseString;
@property (readonly) NSString *capitalizedString;
+ (instancetype)stringWithFormat:(NSString *)format, ...;
+ (instancetype)stringWithUTF8String:(const char *)cString;
+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSUInteger)encoding error:(NSError **)error;
- (instancetype)initWithFormat:(NSString *)format, ...;
- (instancetype)initWithFormat:(NSString *)format arguments:(va_list)args;
- (instancetype)initWithString:(NSString *)other;
- (instancetype)initWithUTF8String:(const char *)cString;
- (BOOL)hasPrefix:(NSString *)prefix;
- (BOOL)hasSuffix:(NSString *)suffix;
- (BOOL)containsString:(NSString *)needle;
- (BOOL)isEqualToString:(NSString *)other;
- (NSArray *)componentsSeparatedByString:(NSString *)separator;
- (NSString *)stringByAppendingString:(NSString *)other;
- (NSString *)stringByAppendingFormat:(NSString *)format, ...;
- (NSString *)stringByAppendingPathComponent:(NSString *)component;
- (NSString *)stringByAppendingPathExtension:(NSString *)extension;
- (NSString *)substringFromIndex:(NSUInteger)index;
- (NSString *)substringToIndex:(NSUInteger)index;
- (struct _NSRange)rangeOfString:(NSString *)needle;
- (NSComparisonResult)compare:(NSString *)other;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag encoding:(NSUInteger)encoding error:(NSError **)error;
- (NSData *)dataUsingEncoding:(NSUInteger)encoding;
- (id)valueForKey:(NSString *)key;
- (NSUInteger)lengthOfBytesUsingEncoding:(NSUInteger)encoding;
@end

typedef struct _NSRange { NSUInteger location; NSUInteger length; } NSRange;

@interface NSMutableString : NSString
+ (instancetype)stringWithCapacity:(NSUInteger)capacity;
- (void)appendString:(NSString *)string;
- (void)appendFormat:(NSString *)format, ...;
@end

@interface NSNumber : NSObject
@property (readonly) int intValue;
@property (readonly) unsigned int unsignedIntValue;
@property (readonly) long longValue;
@property (readonly) NSInteger integerValue;
@property (readonly) unsigned long long unsignedLongLongValue;
@property (readonly) double doubleValue;
@property (readonly) float floatValue;
@property (readonly) BOOL boolValue;
@property (readonly) NSUInteger unsignedIntegerValue;
+ (NSNumber *)numberWithInteger:(NSInteger)value;
+ (NSNumber *)numberWithDouble:(double)value;
+ (NSNumber *)numberWithInteger:(NSInteger)value;
+ (NSNumber *)numberWithDouble:(double)value;
+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)value;
+ (NSNumber *)numberWithLongLong:(long long)value;
+ (NSNumber *)numberWithInt:(int)value;
+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value;
+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)value;
+ (NSNumber *)numberWithBool:(BOOL)value;
+ (NSNumber *)numberWithLong:(long)value;
@end

@interface NSData : NSObject <NSCopying>
@property (readonly) const void *bytes;
@property (readonly) NSUInteger length;
+ (instancetype)dataWithBytes:(const void *)bytes length:(NSUInteger)length;
+ (instancetype)dataWithContentsOfFile:(NSString *)path;
+ (instancetype)dataWithContentsOfFile:(NSString *)path options:(NSUInteger)options error:(NSError **)error;
+ (instancetype)dataWithData:(NSData *)other;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag;
- (BOOL)writeToFile:(NSString *)path options:(NSUInteger)options error:(NSError **)error;
@end

@interface NSMutableData : NSData
@property (readonly) void *mutableBytes;
@end

@interface NSDate : NSObject <NSCopying>
+ (instancetype)date;
- (NSTimeInterval)timeIntervalSinceNow;
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)other;
- (NSComparisonResult)compare:(NSDate *)other;
@end
@interface NSArray<__covariant ObjectType> : NSObject <NSFastEnumeration>
@property (readonly) NSUInteger count;
@property (readonly) ObjectType firstObject;
@property (readonly) ObjectType lastObject;
+ (instancetype)array;
+ (instancetype)arrayWithObjects:(const ObjectType [])objects count:(NSUInteger)cnt;
+ (instancetype)arrayWithObject:(ObjectType)object;
+ (instancetype)arrayWithObjects:(ObjectType)firstObject, ...;
+ (instancetype)arrayWithObjects:(ObjectType)firstObject, ...;
+ (instancetype)arrayWithArray:(NSArray<ObjectType> *)array;
- (ObjectType)objectAtIndex:(NSUInteger)index;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)index;
- (BOOL)containsObject:(ObjectType)object;
- (NSUInteger)countByEnumeratingWithState:(void *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len;
- (NSArray *)sortedArrayUsingSelector:(SEL)comparator;
- (NSArray *)sortedArrayUsingComparator:(NSInteger (^)(id, id))comparator;
- (NSArray *)reverseObjectEnumerator;
- (NSEnumerator *)objectEnumerator;
- (NSString *)componentsJoinedByString:(NSString *)separator;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag;
- (void)enumerateObjectsUsingBlock:(void (^)(ObjectType object, NSUInteger index, BOOL *stop))block;
- (NSUInteger)indexOfObject:(ObjectType)object;
@end

@interface NSEnumerator<ObjectType> : NSObject
- (ObjectType)nextObject;
@end

@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
- (void)addObject:(ObjectType)object;
- (void)addObjectsFromArray:(NSArray<ObjectType> *)array;
- (void)removeObject:(ObjectType)object;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)removeAllObjects;
- (void)insertObject:(ObjectType)object atIndex:(NSUInteger)index;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(ObjectType)object;
@end

@interface NSDictionary<__covariant KeyType, __covariant ObjectType> : NSObject <NSFastEnumeration>
@property (readonly) NSUInteger count;
+ (instancetype)dictionary;
+ (instancetype)dictionaryWithObjects:(const ObjectType [])objects forKeys:(const KeyType [])keys count:(NSUInteger)cnt;
+ (instancetype)dictionaryWithObject:(ObjectType)object forKey:(KeyType)key;
+ (instancetype)dictionaryWithDictionary:(NSDictionary *)other;
- (ObjectType)objectForKey:(KeyType)key;
- (ObjectType)objectForKeyedSubscript:(KeyType)key;
- (NSArray<KeyType> *)allKeys;
- (NSArray<ObjectType> *)allValues;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(KeyType key, ObjectType object, BOOL *stop))block;
@end

@interface NSMutableDictionary<KeyType, ObjectType> : NSDictionary<KeyType, ObjectType>
- (void)setObject:(ObjectType)object forKey:(KeyType)key;
- (void)setObject:(ObjectType)object forKeyedSubscript:(KeyType)key;
- (void)removeObjectForKey:(KeyType)key;
- (void)removeAllObjects;
@end

@interface NSSet<ObjectType> : NSObject
+ (instancetype)set;
+ (instancetype)setWithArray:(NSArray<ObjectType> *)array;
- (BOOL)containsObject:(ObjectType)object;
- (NSUInteger)count;
@end

@interface NSMutableSet<ObjectType> : NSSet<ObjectType>
- (void)addObject:(ObjectType)object;
@end

@interface NSError : NSObject
@property (readonly, copy) NSString *domain;
@property (readonly) NSInteger code;
@property (readonly, copy) NSDictionary *userInfo;
@property (readonly, copy) NSString *localizedDescription;
+ (instancetype)errorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)userInfo;
@end

extern NSString *const NSPOSIXErrorDomain;
typedef NSUInteger NSStringEncoding;
static const NSStringEncoding NSUTF8StringEncoding = 4;
typedef NSUInteger NSPropertyListMutabilityOptions;
static const NSPropertyListMutabilityOptions NSPropertyListImmutable = 0;
typedef NSUInteger NSSearchPathDirectory;
typedef NSUInteger NSSearchPathDomainMask;
static const NSSearchPathDirectory NSLibraryDirectory = 5;
static const NSSearchPathDomainMask NSUserDomainMask = 1;
NSArray *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);
NSString *NSTemporaryDirectory(void);

@interface NSURL : NSObject
@property (readonly, copy) NSString *path;
@property (readonly, copy) NSString *lastPathComponent;
+ (instancetype)fileURLWithPath:(NSString *)path;
@end

@interface NSUUID : NSObject
+ (NSUUID *)UUID;
@property (readonly, copy) NSString *UUIDString;
@end

@interface NSException : NSObject
@property (readonly, copy) NSString *name;
@end

@interface NSCharacterSet : NSObject
+ (instancetype)characterSetWithCharactersInString:(NSString *)string;
@property (readonly) NSCharacterSet *invertedSet;
@end

typedef NSUInteger NSPropertyListFormat;
typedef NSPropertyListFormat NSPropertyListMutabilityOptions;

@interface NSPropertyListSerialization : NSObject
+ (id)propertyListWithData:(NSData *)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error;
+ (NSData *)dataWithPropertyList:(id)plist format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error;
@end

typedef NSUInteger NSPropertyListWriteOptions;
extern const NSPropertyListFormat NSPropertyListBinaryFormat_v1_0;

@interface NSJSONSerialization : NSObject
+ (id)JSONObjectWithData:(NSData *)data options:(NSUInteger)options error:(NSError **)error;
@end

@interface NSFileManager : NSObject
+ (instancetype)defaultManager;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)contents attributes:(NSDictionary *)attributes;
- (BOOL)copyItemAtPath:(NSString *)source toPath:(NSString *)destination error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)setAttributes:(NSDictionary *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error;
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
@end

extern NSString *const NSFileType;
extern NSString *const NSFileTypeDirectory;
extern NSString *const NSFileTypeRegular;
extern NSString *const NSFileTypeSymbolicLink;
extern NSString *const NSFilePosixPermissions;
extern NSString *const NSFileProtectionKey;
extern NSString *const NSFileModificationDate;

@interface NSFileHandle : NSObject
+ (instancetype)fileHandleForReadingAtPath:(NSString *)path;
+ (instancetype)fileHandleForWritingAtPath:(NSString *)path;
+ (instancetype)fileHandleForWritingToURL:(NSURL *)url error:(NSError **)error;
- (NSData *)readDataOfLength:(NSUInteger)length;
- (void)writeData:(NSData *)data;
- (void)seekToEndOfFile;
- (void)synchronizeFile;
- (void)closeAndReturnError:(NSError **)error;
- (void)closeFile;
@end

@interface NSBundle : NSObject
+ (instancetype)mainBundle;
@property (readonly, copy) NSString *bundlePath;
@property (readonly, copy) NSString *bundleIdentifier;
@property (readonly) NSDictionary *infoDictionary;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)extension;
@end

typedef struct { NSInteger majorVersion; NSInteger minorVersion; NSInteger patchVersion; } NSOperatingSystemVersion;

@interface NSProcessInfo : NSObject
+ (instancetype)processInfo;
@property (readonly) NSOperatingSystemVersion operatingSystemVersion;
@property (readonly) NSString *operatingSystemVersionString;
@end

@interface NSUserDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (NSString *)stringForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
@end

@interface NSDateFormatter : NSObject
@property (copy) NSString *dateFormat;
- (NSString *)stringFromDate:(NSDate *)date;
@end

@interface NSISO8601DateFormatter : NSObject
- (NSString *)stringFromDate:(NSDate *)date;
@end

@interface NSLock : NSObject
- (void)lock;
- (void)unlock;
@end

@interface NSAttributedString : NSObject
- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes;
@end

@interface NSMutableAttributedString : NSAttributedString
@end

extern NSString *const NSLocalizedDescriptionKey;
extern NSString *const NSFontAttributeName;
extern NSString *const NSForegroundColorAttributeName;
extern NSString *const NSKernAttributeName;

typedef void (^dispatch_block_t)(void);
typedef void *dispatch_once_t;
typedef void *dispatch_queue_t;
typedef void *dispatch_group_t;
typedef void *dispatch_time_t;
extern dispatch_queue_t dispatch_get_main_queue(void);
extern dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
extern void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
extern void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
extern void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);
extern dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta);
extern void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
#define DISPATCH_TIME_NOW 0ull
#define NSEC_PER_SEC 1000000000ull
#define QOS_CLASS_USER_INITIATED 0x19
#define QOS_CLASS_UTILITY 0x11
#define QOS_CLASS_BACKGROUND 0x09

typedef void *os_log_t;

@interface NSThread : NSObject
+ (void)sleepForTimeInterval:(NSTimeInterval)interval;
@end

#endif
