#import "APIObject.h"
#import "KSDeferred.h"
#import <objc/message.h>
#import "APICollection.h"
#import "APIObjectParser.h"
#import "APISyncableEntity.h"
#import "APIEntitySyncer.h"
#import "BlockRunner.h"
#import "NSString+APIObject.h"

@interface APIObject ()

@property (nonatomic, strong) APIObjectParser *parser;
@property (nonatomic, strong) APIEntitySyncer *syncer;

@end


static NSMutableDictionary *currentCache;
static dispatch_queue_t kAPIObjectSaveQueue;


@implementation APIObject

+ (void)load
{
    currentCache = [@{} mutableCopy];
    kAPIObjectSaveQueue = dispatch_queue_create("com.APIObject.saveObject", DISPATCH_QUEUE_SERIAL);
}

#pragma mark - Initialize

+ (void)initialize
{
    for (NSString *property in [self objectToNetworkKeyMap]) {
        NSString *setterSELString = [property setterString];
        SEL setterSEL = NSSelectorFromString(setterSELString);
        SEL _setterSEL = NSSelectorFromString([@"_" stringByAppendingString:setterSELString]);

        Method originalSetter = class_getInstanceMethod(self, _setterSEL);
        if (originalSetter == NULL) originalSetter = class_getInstanceMethod(self, setterSEL);
        IMP originalSetterIMP = method_getImplementation(originalSetter);

        IMP observerSetterIMP = imp_implementationWithBlock(^(APIObject *me, id newValue) {
            if (me.state == APISyncableEntityStateSynced) me.state = APISyncableEntityStateDirty;
            void (*setPropertyValue)(id, SEL, id) = (void (*)(id, SEL, id)) objc_msgSend;
            setPropertyValue(me, _setterSEL, newValue);
        });

        class_replaceMethod(self, _setterSEL, originalSetterIMP, method_getTypeEncoding(originalSetter));
        class_replaceMethod(self, setterSEL, observerSetterIMP, method_getTypeEncoding(originalSetter));
    };
}

#pragma mark - Public Configuration

+ (NSString *)resourcePath
{
    return nil;
}

+ (NSString *)resourceName
{
    return nil;
}

+ (SEL)resourceIdentifier
{
    return nil;
}

+ (NSDictionary *)objectToNetworkKeyMap
{
    return nil;
}

#pragma mark - Public Class Methods

+ (instancetype)existing
{
    APIObject *existingObject = [self new];
    existingObject.state = APISyncableEntityStateExisting;
    
    return existingObject;
}

+ (instancetype)fromDictionary:(NSDictionary *)networkDictionary
{
    APIObject *apiObject = [self new];
    [apiObject _parseAndMarkAsSynced:@{[self resourceName]: networkDictionary}];
    
    return apiObject;
}

- (void)parseDictionary:(NSDictionary *)networkDictionary
{
    [self _parseAndMarkAsSynced:@{[self.class resourceName]: networkDictionary}];
}

- (void)parseNetworkValue:(id)networkValue
{
    [self parseDictionary:networkValue];
}

- (id)toNetworkValue
{
    return [self toNetworkDictionary];
}

- (NSDictionary *)toNetworkDictionary
{
    return [self.parser objectToNetworkDictionary];
}

+ (id)identifierFromDictionary:(NSDictionary *)networkDictionary
{
    NSString *identifier = NSStringFromSelector([self resourceIdentifier]);
    NSString *networkIdentifier = [self objectToNetworkKeyMap][identifier];
    return networkDictionary[networkIdentifier];
}

#pragma mark - Private Class Methods

+ (NSURL *)currentPath
{
    NSURL *applicationDocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                                   inDomains:NSUserDomainMask] lastObject];
    return [applicationDocumentsDirectory URLByAppendingPathComponent:[self currentKey]];
}

+ (NSString *)currentKey
{
    return [NSString stringWithFormat:@"APIObject%@%@", NSStringFromClass(self), @"Current"];
}

#pragma mark - Public Instance Methods

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithOwner:(APIObject *)owner
{
    self = [self init];
    if (self) {
        self.object = owner;
    }
    return self;
}

@synthesize validationErrors = _validationErrors;
@synthesize state = _state;

- (void)commonInit
{
    self.parser = [[APIObjectParser alloc] initWithAPIObject:self];
    self.syncer = [[APIEntitySyncer alloc] initWithSyncableEntity:self];
    self.validationErrors = [NSMutableArray new];
    self.state = APISyncableEntityStateNew;
}

- (NSString *)resourcePath
{
    NSString *resourcePath;
    if (self.collection) {
        resourcePath = self.collection.resourcePath;
    } else if (self.object) {
        resourcePath = [self.object.resourcePath stringByAppendingPathComponent:[self.class resourcePath]];
    } else {
        resourcePath = [self.class resourcePath];
    }
    
    SEL identifierSEL = [[self class] resourceIdentifier];
    id (*getObjectIdentifier)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
    id identifier = (identifierSEL ? getObjectIdentifier(self, identifierSEL) : @"");
    NSString *identifierString = [NSString stringWithFormat:@"%@", identifier];
    
    return [resourcePath stringByAppendingPathComponent:(identifier ? identifierString : @"")];
}

- (id)identifier
{
    id (*getObjectIdentifier)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
    return getObjectIdentifier(self, [self.class resourceIdentifier]);
}

- (BOOL)validate
{
    [self.validationErrors removeAllObjects];
    
    [[[self class] objectToNetworkKeyMap] enumerateKeysAndObjectsUsingBlock:
     ^(NSString *objectProperty, id value, BOOL *stop) {
         NSString *validatorSelectorString = [@"validate" stringByAppendingString:objectProperty.capitalFirstLetterString];
         SEL validatorSelector = NSSelectorFromString(validatorSelectorString);
         
         if ([self respondsToSelector:validatorSelector]) {
             id (*getErrorMessage)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
             NSString *errorMessage = getErrorMessage(self, validatorSelector);
             if (errorMessage) {
                 NSError *error = [NSError errorWithDomain:APIEntitySyncErrorDomain
                                                      code:APIEntitySyncErrorCodeValidationFailure
                                                  userInfo:@{
                                                             NSLocalizedDescriptionKey: NSLocalizedString(errorMessage, nil),
                                                             NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Validation Failure", nil),
                                                             NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Change value of property failing validation", nil)
                                                             }];
                 [self.validationErrors addObject:error];
             }
         }
     }];
    
    return self.validationErrors.count == 0;
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
    APICollection *originalCollection = self.collection;
    return [[self.syncer destroy]
            then:^id(APIObject *me) {
                [originalCollection removeObjects:@[me]];
                return me;
            }
            error:NULL];
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

- (APISyncableEntityState)syncState
{
    return self.state;
}

#pragma mark - <NSCoding>

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        [self commonInit];
        
        self.state = [[coder decodeObjectForKey:[self coderKeyForObjectProperty:@"_syncState"]] integerValue];
        for (NSString *objectProperty in [[self class] objectToNetworkKeyMap]) {
            SEL objectPropertySetter = NSSelectorFromString(objectProperty.setterString);
            id objectPropertyValue = [coder decodeObjectForKey:[self coderKeyForObjectProperty:objectProperty]];
            
            SEL objectPropertyGetter = NSSelectorFromString(objectProperty);
            id (*getObjectProperty)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
            id currentObjectPropertyValue = getObjectProperty(self, objectPropertyGetter);
            
            if (objectPropertyValue && (!currentObjectPropertyValue || [currentObjectPropertyValue class] == [objectPropertyValue class])) {
                void (*setObjectProperty)(id, SEL, id) = (void (*)(id, SEL, id)) objc_msgSend;
                setObjectProperty(self, objectPropertySetter, objectPropertyValue);
            }
            
            if ([objectPropertyValue isKindOfClass:[APICollection class]] || [objectPropertyValue isKindOfClass:[APIObject class]]) {
                [(id)objectPropertyValue setObject:self];
            }
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    __weak typeof(self)me = self;
    [[[self class] objectToNetworkKeyMap] enumerateKeysAndObjectsUsingBlock:
     ^(NSString *objectProperty, id value, BOOL *stop) {
         SEL objectPropertyGetter = NSSelectorFromString(objectProperty);
         
         id (*getObjectProperty)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
         id objectPropertyValue = getObjectProperty(me, objectPropertyGetter);
         [coder encodeObject:objectPropertyValue forKey:[me coderKeyForObjectProperty:objectProperty]];
     }];
    [coder encodeObject:@(self.state) forKey:[self coderKeyForObjectProperty:@"_syncState"]];
}

- (NSString *)coderKeyForObjectProperty:(NSString *)property
{
    return [NSStringFromClass([self class]) stringByAppendingString:property];
}

#pragma mark - <APISyncableEntity>

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
