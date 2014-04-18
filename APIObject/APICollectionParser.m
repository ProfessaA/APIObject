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
    NSMutableArray *objectsJSON = [@[] mutableCopy];
    
    for (id<APISyncableEntity> entity in self.collection.objects) {
        [objectsJSON addObject:[entity.parser objectToNetworkDictionary]];
    }
    
    return @{
             self.collection.resourceName : objectsJSON
             };
}

- (void)networkDictionaryToObject:(NSDictionary *)networkDictionary
{
    NSArray *networkJSONObjects = networkDictionary[self.collection.resourceName];
    
    if (![networkJSONObjects isKindOfClass:[NSArray class]]) return;
    
    [self.collection lockObjects];
    NSMutableArray *objectsToKeep = [@[] mutableCopy];
    for (NSDictionary *objectJSON in networkJSONObjects) {
        APIObject *object;
        id identifier = [[self.collection.class objectClass] identifierFromJSON:objectJSON];
        if (identifier == [NSNull null]) identifier = nil;
        
        if ((object = [self.collection objectWithIdentifier:identifier]) != nil) {
            [object parse:objectJSON];
        } else {
            object = [[self.collection.class objectClass] fromJSON:objectJSON];
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
