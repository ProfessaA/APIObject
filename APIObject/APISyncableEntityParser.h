#import <Foundation/Foundation.h>

@protocol APISyncableEntityParser <NSObject>

- (NSDictionary *)objectToNetworkDictionary;
- (void)networkDictionaryToObject:(NSDictionary *)networkDictionary;

@end
