#import "NSString+APIObject.h"

@implementation NSString (APIObject)

- (NSString *)capitalFirstLetterString
{
    return [self stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[self substringToIndex:1].uppercaseString];
}

- (NSString *)setterString
{
    return [@"set" stringByAppendingFormat:@"%@:", self.capitalFirstLetterString];
}

@end
