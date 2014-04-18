#import <Foundation/Foundation.h>
#import "APISyncableEntityParser.h"

@class APICollection;

@interface APICollectionParser : NSObject <APISyncableEntityParser>

- (id)initWithCollection:(APICollection *)collection;

@end
