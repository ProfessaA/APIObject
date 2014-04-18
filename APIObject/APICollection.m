#import "APICollection.h"
#import "APIObject.h"
#import "APIEntitySyncer.h"
#import "APICollectionParser.h"
#import <objc/message.h>

@interface APICollection ()

@property (nonatomic, strong) NSMutableArray *mutableObjects;
@property (nonatomic, strong) APIEntitySyncer *syncer;
@property (nonatomic, strong) APICollectionParser *parser;
@property (nonatomic, strong) NSArray *lockedObjects;

@end

@implementation APICollection

+ (Class)objectClass
{
    return nil;
}

+ (NSString *)resourcePath
{
    return [[self objectClass] resourcePath];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (NSString *)resourceName
{
    return @"";
}

- (instancetype)initWithOwner:(APIObject *)owner
{
    self = [self init];
    if (self) {
        self.object = owner;
        self.state = APISyncableEntityStateNew;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        [self commonInit];
        NSMutableArray *objects = [aDecoder decodeObjectForKey:[NSStringFromClass(self.class) stringByAppendingString:@"Objects"]];
        for (APIObject *object in objects) {
            object.collection = self;
        }
        self.mutableObjects = objects;
        self.state = APISyncableEntityStateSynced;
    }
    
    return self;
}

- (void)commonInit
{
    self.syncer = [[APIEntitySyncer alloc] initWithSyncableEntity:self];
    self.parser = [[APICollectionParser alloc] initWithCollection:self];
    self.mutableObjects = [@[] mutableCopy];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[self.mutableObjects mutableCopy] forKey:[NSStringFromClass(self.class) stringByAppendingString:@"Objects"]];
}

- (NSString *)resourcePath
{
    NSString *objectResourcePath = (self.object ? self.object.resourcePath : @"");
    return [objectResourcePath stringByAppendingPathComponent:[self.class resourcePath]];
}

- (id)buildObject
{
    APIObject *newObject = [[self.class objectClass] new];
    [self addObject:newObject];
    
    return newObject;
}

- (void)_parseAndMarkAsSynced:(NSDictionary *)networkResponseDictionary
{
    [self parse:networkResponseDictionary];
    self.state = APISyncableEntityStateSynced;
}

- (void)parse:(NSDictionary *)networkResponseDictionary
{
    [self.parser networkDictionaryToObject:networkResponseDictionary];
}

- (void)parseArray:(NSArray *)networkObjectsArray
{
    [self _parseAndMarkAsSynced:@{self.resourceName: networkObjectsArray}];
}

- (void)parseNetworkValue:(id)networkValue
{
    [self parseArray:networkValue];
}

- (id)toNetworkValue
{
    return [self toNetworkArray];
}

- (NSDictionary *)toNetworkArray
{
    return [self.parser objectToNetworkDictionary][self.resourceName];
}

- (NSArray *)objects
{
    return self.lockedObjects ? self.lockedObjects : [self.mutableObjects copy];
}

- (id)objectWithIdentifier:(id)identifier
{
    SEL identifierSEL = [[self.class objectClass] resourceIdentifier];
    if (identifierSEL == nil) return nil;
    
    return [self.objects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(APIObject *object, NSDictionary *bindings) {
        
        id (*getObjectIdentifier)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
        return [getObjectIdentifier(object, identifierSEL) isEqual:identifier];
    }]].firstObject;
}

- (void)removeObjects:(NSArray *)objectsToRemove
{
    [self.mutableObjects removeObjectsInArray:objectsToRemove];
}

- (void)addObject:(APIObject *)object
{
    if (object == nil) return;
    [self.mutableObjects addObject:object];
    object.state = APISyncableEntityStateNew;
    object.collection = self;
}

- (void)orderWithBlock:(NSComparisonResult(^)(APIObject *obj1, APIObject *obj2))comparisonBlock
{
    [self.mutableObjects sortUsingComparator:comparisonBlock];
}

- (NSArray *)objectsInState:(APISyncableEntityState)state
{
    NSPredicate *objectsInState = [NSPredicate predicateWithBlock:^BOOL(APIObject *apiObject, NSDictionary *bindings) {
        return apiObject.syncState == state;
    }];
    
    return [self.objects filteredArrayUsingPredicate:objectsInState];
}

- (void)lockObjects
{
    self.lockedObjects = [self.mutableObjects copy];
}

- (void)unlockObjects
{
    self.lockedObjects = nil;
}

- (KSPromise *)sync
{
    return [self.syncer sync];
}

- (KSPromise *)fetch
{
    return [self.syncer fetch];
}

- (KSPromise *)save
{
    return [self.syncer save];
}

- (KSPromise *)destroy
{
    return [self.syncer destroy];
}

#pragma mark - <APISyncableEntity>

@synthesize state = _state;

- (NSString *)pathForCreate
{
    return self.resourcePath;
}

- (NSString *)pathForUpdate
{
    return self.resourcePath;
}

- (NSString *)pathForRead
{
    return self.resourcePath;
}

- (NSString *)pathForDestroy
{
    return self.resourcePath;
}

@end
