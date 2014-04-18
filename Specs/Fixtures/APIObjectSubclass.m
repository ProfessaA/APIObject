#import "APIObjectSubclass.h"

@implementation APIObjectSubclass

+ (NSString *)resourceName
{
    return @"APIObjectSubclass";
}

+ (NSDictionary *)objectToNetworkKeyMap
{
    return @{
             @"property1" : @"network_property_1",
             @"property2" : @"network_property_2"
             };
}

+ (NSString *)resourcePath
{
    return @"APIObjectSubclasses";
}

+ (SEL)resourceIdentifier
{
    return @selector(property1);
}

@end
