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
+ (instancetype)fromDictionary:(NSDictionary *)networkDictionary;
+ (id)identifierFromDictionary:(NSDictionary *)networkDictionary;

#pragma mark - Instance Methods
@property (nonatomic, assign, readonly) APISyncableEntityState syncState;
@property (nonatomic, weak) APICollection *collection;
@property (nonatomic, weak) APIObject *object;

- (void)commonInit NS_REQUIRES_SUPER;

- (void)parseDictionary:(NSDictionary *)networkDictionary;
- (NSDictionary *)toNetworkDictionary;

- (id)identifier;
- (NSString *)resourcePath;
- (BOOL)validate;

@end
