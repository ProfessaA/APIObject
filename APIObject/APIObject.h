#import <Foundation/Foundation.h>
#import "APISyncableEntity.h"


@class KSPromise, AFHTTPSessionManager, APICollection;


@interface APIObject : NSObject <NSCoding, APISyncableEntity>

#pragma mark - Class Configuration
+ (NSString *)resourcePath;
+ (NSString *)resourceName;
+ (SEL)resourceIdentifier;
+ (NSDictionary *)objectToNetworkKeyMap;

#pragma mark - Class Methods
+ (instancetype)existing;
+ (instancetype)fromJSON:(NSDictionary *)networkJSON;
+ (id)identifierFromJSON:(NSDictionary *)networkJSON;

#pragma mark - Instance Methods
@property (nonatomic, assign, readonly) APISyncableEntityState syncState;
@property (nonatomic, weak) APICollection *collection;
@property (nonatomic, weak) APIObject *object;

- (void)commonInit NS_REQUIRES_SUPER;

- (void)parse:(NSDictionary *)networkJSON;
- (NSDictionary *)toJSON;

- (id)identifier;
- (NSString *)resourcePath;
- (BOOL)validate;

@end
