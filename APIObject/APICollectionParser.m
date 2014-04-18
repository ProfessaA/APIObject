#import "APICollectionParser.h"
#import "APICollection.h"
#import "APIObject.h"
#import "APISyncableEntity.h"

@interface APICollectionParser ()

@property (nonatomic, weak) APICollection *collection;

@end

@implementation APICollectionParser

- (id)initWithCollection:(APICollection *)collection
{
    self = [super init];
    if (self) {
        self.collection = collection;
    }
    return self;
}

- (NSDictionary *)objectToNetworkDictionary
{
    NSMutableArray *networkObjectsArray = [@[] mutableCopy];
    
    for (id<APISyncableEntity> entity in self.collection.objects) {
        [networkObjectsArray addObject:[entity.parser objectToNetworkDictionary]];
    }
    
    return @{
             self.collection.resourceName : networkObjectsArray
             };
}

- (void)networkDictionaryToObject:(NSDictionary *)networkDictionary
{
    NSArray *networkObjectsArray = networkDictionary[self.collection.resourceName];
    
    if (![networkObjectsArray isKindOfClass:[NSArray class]]) return;
    
    [self.collection lockObjects];
    NSMutableArray *objectsToKeep = [@[] mutableCopy];
    for (NSDictionary *networkObjectDictionary in networkObjectsArray) {
        APIObject *object;
        id identifier = [[self.collection.class objectClass] identifierFromDictionary:networkObjectDictionary];
        if (identifier == [NSNull null]) identifier = nil;
        
        if ((object = [self.collection objectWithIdentifier:identifier]) != nil) {
            [object parseDictionary:networkObjectDictionary];
        } else {
            object = [[self.collection.class objectClass] fromDictionary:networkObjectDictionary];
            [self.collection addObject:object];
            object.state = APISyncableEntityStateSynced;
        }
        
        object.collection = self.collection;
        [objectsToKeep addObject:object];
    }
    
    NSArray *objectsToRemove = [self.collection.objects filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
                                                                                     ^BOOL(APIObject *object, NSDictionary *bindings) {
                                                                                         return ![objectsToKeep containsObject:object];
                                                                                     }]];
    [self.collection removeObjects:objectsToRemove];
    
    if ([self.collection respondsToSelector:@selector(orderAfterParse)]) {
        [self.collection orderAfterParse];
    } else {
        [self.collection orderWithBlock:^NSComparisonResult(APIObject *obj1, APIObject *obj2) {
            return [objectsToKeep indexOfObject:obj1] < [objectsToKeep indexOfObject:obj2] ? NSOrderedAscending : NSOrderedDescending;
        }];
    }
    
    [self.collection unlockObjects];
}

@end
