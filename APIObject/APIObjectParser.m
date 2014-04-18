#import "APIObjectParser.h"
#import "APIObject.h"
#import <objc/message.h>
#import "APICollection.h"
#import "APISyncableEntity.h"
#import "NSString+APIObject.h"

@interface APIObjectParser ()

@property (weak, nonatomic) APIObject *apiObject;

@end

@implementation APIObjectParser

- (instancetype)initWithAPIObject:(APIObject *)apiObject
{
    self = [super init];
    if (self) {
        self.apiObject = apiObject;
    }
    return self;
}

- (NSDictionary *)objectToNetworkDictionary
{
    NSMutableDictionary *networkDictionary = [@{} mutableCopy];
    
    [[[self.apiObject class] objectToNetworkKeyMap] enumerateKeysAndObjectsUsingBlock:
     ^(NSString *objectProperty, NSString *networkProperty, BOOL *stop) {
         SEL propertySEL = NSSelectorFromString(objectProperty);
         SEL networkValSEL = NSSelectorFromString([objectProperty stringByAppendingString:@"NetworkValue"]);
         propertySEL = [self.apiObject respondsToSelector:networkValSEL] ? networkValSEL : propertySEL;
         
         id (*getObjectProperty)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
         id value = getObjectProperty(self.apiObject, propertySEL);
         
         if ([value conformsToProtocol:@protocol(APISyncableEntity)]) {
             value = [((id<APISyncableEntity>)value) toNetworkValue];
         }
         
         if (value) networkDictionary[networkProperty] = value;
     }];
    
    return networkDictionary;
}

- (void)networkDictionaryToObject:(NSDictionary *)networkDictionary
{
    NSDictionary *resourceDictionary = [networkDictionary objectForKey:[[self.apiObject class] resourceName]];
    
    if (![resourceDictionary isKindOfClass:[NSDictionary class]]) return;
    
    for (NSString *objectProperty in [self.apiObject.class objectToNetworkKeyMap]) {
        NSString *networkProperty = [self.apiObject.class objectToNetworkKeyMap][objectProperty];
        
        id (*getObjectProperty)(id, SEL) = (id (*)(id, SEL)) objc_msgSend;
        id propertyValue = getObjectProperty(self.apiObject, NSSelectorFromString(objectProperty));
        id networkPropertyValue = resourceDictionary[networkProperty];
        
        NSString *propertySetterString = objectProperty.setterString;
        SEL propertySetterSEL = NSSelectorFromString(propertySetterString);
        
        if (networkPropertyValue == nil || networkPropertyValue == [NSNull null]) continue;
        
        if ([propertyValue conformsToProtocol:@protocol(APISyncableEntity)]) {
            [(id<APISyncableEntity>)propertyValue parseNetworkValue:networkPropertyValue];
        } else if ([self.apiObject respondsToSelector:propertySetterSEL]) {
            void (*setPropertyValue)(id, SEL, id) = (void (*)(id, SEL, id)) objc_msgSend;
            setPropertyValue(self.apiObject, propertySetterSEL, networkPropertyValue);
        }
    }
}

@end
