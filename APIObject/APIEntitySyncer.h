#import <Foundation/Foundation.h>
#import "APISyncableEntity.h"


@class AFHTTPSessionManager, KSPromise;
@protocol APIHTTPClient;

extern NSString * const APIEntitySyncErrorDomain;

typedef NS_ENUM(NSUInteger, APIEntitySyncErrorCode) {
    APIEntitySyncErrorCodeValidationFailure,
    APIEntitySyncErrorCodeSyncFailure
};


@interface APIEntitySyncer : NSObject

#pragma mark - Public Configuration

+ (void)setBaseURLWithString:(NSString *)baseURLString;
+ (void)setSharedHTTPClient:(id<APIHTTPClient>)sharedHTTPClient;
+ (void)setSharedHeaderField:(NSString *)headerField withValue:(NSString *)value;

#pragma mark - Public Instance Methods
- (id)initWithSyncableEntity:(id <APISyncableEntity>)syncableEntity;
- (KSPromise *)sync;
- (KSPromise *)save;
- (KSPromise *)fetch;
- (KSPromise *)destroy;

@end
