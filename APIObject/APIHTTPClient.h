#import <Foundation/Foundation.h>

@class KSPromise;

typedef NS_ENUM(NSUInteger, APIHTTPMethod) {
    APIHTTPMethodGET,
    APIHTTPMethodPOST,
    APIHTTPMethodPUT,
    APIHTTPMethodDELETE
};

static NSString const* APIHTTPErrorMessageKey = @"APIHTTPErrorMessageKey";

@protocol APIHTTPClient

- (KSPromise *)makeRequestToEndpoint:(NSString *)endpoint withMethod:(APIHTTPMethod)httpMethod params:(NSDictionary *)params;
- (void)setHeaderField:(NSString *)headerField withValue:(NSString *)value;

@end
