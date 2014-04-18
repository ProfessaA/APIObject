#import <Foundation/Foundation.h>
#import "APISyncableEntityParser.h"

@class APIObject;

@interface APIObjectParser : NSObject <APISyncableEntityParser>

- (instancetype)initWithAPIObject:(APIObject *)apiObject;

@end
