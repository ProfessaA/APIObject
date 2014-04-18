#import <Foundation/Foundation.h>
#import "APISyncableEntity.h"


@class APIObject, KSPromise;


@interface APICollection : NSObject <NSCoding, APISyncableEntity>

+ (Class)objectClass;
+ (NSString *)resourcePath;

@property (nonatomic, strong, readonly) NSString *resourcePath;
@property (nonatomic, strong, readonly) NSString *resourceName;
@property (nonatomic, strong, readonly) NSArray *objects;
@property (nonatomic, weak) APIObject *object;

- (void)commonInit NS_REQUIRES_SUPER;

- (NSArray *)toNetworkArray;
- (void)parseArray:(NSArray *)networkObjectsArray;

- (id)buildObject;
- (void)removeObjects:(NSArray *)objectsToRemove;
- (void)addObject:(APIObject *)object;
- (void)orderWithBlock:(NSComparisonResult(^)(APIObject *obj1, APIObject *obj2))comparisonBlock;

- (id)objectWithIdentifier:(id)identifier;
- (NSArray *)objectsInState:(APISyncableEntityState)state;

- (void)lockObjects;
- (void)unlockObjects;

@end
