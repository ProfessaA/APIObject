#import <Foundation/Foundation.h>


@class APIObject, KSPromise;
@protocol APISyncableEntityParser;

typedef NS_ENUM(NSUInteger, APISyncableEntityState) {
    APISyncableEntityStateNew,
    APISyncableEntityStateExisting,
    APISyncableEntityStateSynced,
    APISyncableEntityStateDirty
};


@protocol APISyncableEntity <NSObject>

@property (nonatomic, assign) APISyncableEntityState state;

- (instancetype)initWithOwner:(APIObject *)owner;

- (id<APISyncableEntityParser>)parser;
- (void)parse:(id)networkJSON;
- (NSDictionary *)toJSON;

- (NSString *)pathForCreate;
- (NSString *)pathForUpdate;
- (NSString *)pathForRead;
- (NSString *)pathForDestroy;

- (KSPromise *)sync;
- (KSPromise *)fetch;
- (KSPromise *)save;
- (KSPromise *)destroy;

@optional

@property (nonatomic, strong) NSMutableArray *validationErrors;

- (BOOL)validate;
- (NSDictionary *)paramsForCreate;
- (NSDictionary *)paramsForUpdate;
- (NSDictionary *)paramsForRead;

- (void)orderAfterParse;

- (void)parseJSON:(NSDictionary *)jsonDictionary;

@end
