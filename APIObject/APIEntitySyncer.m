#import "APIEntitySyncer.h"
#import "KSDeferred.h"
#import "APISyncableEntity.h"
#import "APISyncableEntityParser.h"
#import <objc/message.h>
#import "APIObject.h"
#import "APICollection.h"
#import "BlockRunner.h"
#import "APIHTTPClient.h"

@protocol APISyncableEntity_Private<APISyncableEntity>

- (void)_parseAndMarkAsSynced:(NSDictionary *)networkResponseDictionary;

@end

@interface APIEntitySyncer ()

@property (nonatomic, weak) id<APISyncableEntity_Private> syncableEntity;

@end

NSString * const APIEntitySyncErrorDomain = @"APIEntitySyncErrorDomain";
static NSURL *APIEntitySyncerBaseURL;
static id<APIHTTPClient> APIEntitySyncerSharedHTTPClient;
static dispatch_queue_t kAPIEntitySyncerProcessNetworkResponseQueue;

typedef NS_ENUM(NSUInteger, APIEntitySyncerAction) {
    APIEntitySyncerActionCreate,
    APIEntitySyncerActionUpdate,
    APIEntitySyncerActionRead,
    APIEntitySyncerActionDestroy
};


@implementation APIEntitySyncer

+ (void)initialize
{
    kAPIEntitySyncerProcessNetworkResponseQueue = dispatch_queue_create("com.APIObjectEntitySyncer.processNetworkResponse", DISPATCH_QUEUE_SERIAL);
}

- (id)initWithSyncableEntity:(id<APISyncableEntity>)syncableEntity
{
    self = [super init];
    if (self) {
        self.syncableEntity = (id<APISyncableEntity_Private>)syncableEntity;
    }
    return self;
}

#pragma mark - Public Configuration

+ (void)setBaseURLWithString:(NSString *)baseURLString
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        APIEntitySyncerBaseURL = [NSURL URLWithString:baseURLString];
    });
}

+ (void)setSharedHTTPClient:(id<APIHTTPClient>)sharedHTTPClient;
{
    APIEntitySyncerSharedHTTPClient = sharedHTTPClient;
}

+ (void)setSharedHeaderField:(NSString *)headerField withValue:(NSString *)value
{
    [APIEntitySyncerSharedHTTPClient setHeaderField:headerField withValue:value];
}

- (id<APIHTTPClient>)sharedHTTPClient
{
    return APIEntitySyncerSharedHTTPClient;
}

- (KSPromise *)sync
{
    if ([self.syncableEntity respondsToSelector:@selector(validate)] && ![self.syncableEntity validate]) {
        KSDeferred *syncDeferred = [KSDeferred defer];
        [syncDeferred rejectWithError:self.syncableEntity.validationErrors.firstObject];
        return syncDeferred.promise;
    }
    
    switch (self.syncableEntity.state) {
        case APISyncableEntityStateDirty:
        case APISyncableEntityStateNew:
            return [self save];
            
        case APISyncableEntityStateSynced:
        case APISyncableEntityStateExisting:
            return [self fetch];
    }
}

# pragma mark - Private

- (KSPromise *)save
{
    if (self.syncableEntity.state == APISyncableEntityStateSynced && [self.syncableEntity isKindOfClass:[APIObject class]]) {
        KSDeferred *requestDeferred = [KSDeferred defer];
        [requestDeferred resolveWithValue:self.syncableEntity];
        
        return requestDeferred.promise;
    }
    
    APIEntitySyncerAction action = APIEntitySyncerActionUpdate;
    if (self.syncableEntity.state == APISyncableEntityStateNew || [self.syncableEntity isKindOfClass:[APICollection class]]) {
        action = APIEntitySyncerActionCreate;
    }
    
    return [self requestWithAction:action];
}

- (KSPromise *)fetch
{
    return [self requestWithAction:APIEntitySyncerActionRead];
}

- (KSPromise *)destroy
{
    return [self requestWithAction:APIEntitySyncerActionDestroy];
}

- (KSPromise *)requestWithAction:(APIEntitySyncerAction)action
{
    APIHTTPMethod requestMethod;
    NSDictionary *params;
    NSString *endpoint;
    
    switch (action) {
        case APIEntitySyncerActionCreate: {
            
            requestMethod = APIHTTPMethodPOST;
            params = [self.syncableEntity respondsToSelector:@selector(paramsForCreate)] ?
            self.syncableEntity.paramsForCreate :
            [self.syncableEntity.parser objectToNetworkDictionary];
            endpoint = [self.syncableEntity pathForCreate];
            
            break;
        }
            
        case APIEntitySyncerActionUpdate: {
            
            requestMethod = APIHTTPMethodPUT;
            params = [self.syncableEntity respondsToSelector:@selector(paramsForUpdate)] ?
            self.syncableEntity.paramsForUpdate:
            [self.syncableEntity.parser objectToNetworkDictionary];
            endpoint = [self.syncableEntity pathForUpdate];
            
            break;
        }
            
        case APIEntitySyncerActionRead: {
            requestMethod = APIHTTPMethodGET;
            endpoint = [self.syncableEntity pathForRead];
            if ([self.syncableEntity respondsToSelector:@selector(paramsForRead)]) {
                params = [self.syncableEntity paramsForRead];
            }
            
            break;
        }
            
        case APIEntitySyncerActionDestroy: {
            requestMethod = APIHTTPMethodDELETE;
            endpoint = [self.syncableEntity pathForDestroy];
            
            break;
        }
    }
    
    __block KSDeferred *requestDeferred = [KSDeferred defer];
    __strong typeof(self)me = self;
    
    [[self.sharedHTTPClient makeRequestToEndpoint:endpoint withMethod:requestMethod params:params]
     then:^id(NSDictionary *response) {
         [BlockRunner
          runBlock:^{
              if (!me.syncableEntity) {
                  [requestDeferred rejectWithError:[NSError errorWithDomain:APIEntitySyncErrorDomain
                                                                       code:APIEntitySyncErrorCodeSyncFailure
                                                                   userInfo:@{NSLocalizedDescriptionKey: @"An error occured"}]];
              }
              
              [me.syncableEntity _parseAndMarkAsSynced:response];
              
              [BlockRunner runBlock:^{ [requestDeferred resolveWithValue:me.syncableEntity]; } onThread:dispatch_get_main_queue()];
          }
          onThread:kAPIEntitySyncerProcessNetworkResponseQueue];
         
         return nil;
     } error:^id(NSError *error) {
         [BlockRunner
          runBlock:^{
              NSDictionary *response = error.userInfo[APIHTTPErrorMessageKey];
              NSString *errorMessage = NSLocalizedString(@"An Error Occurred", @"Generic Error Description");
              
              NSError *domainError = [NSError errorWithDomain:APIEntitySyncErrorDomain
                                                         code:APIEntitySyncErrorCodeSyncFailure
                                                     userInfo:@{
                                                                NSLocalizedDescriptionKey: response ? response : errorMessage
                                                                }];
              [BlockRunner runBlock:^{ [requestDeferred rejectWithError:domainError]; } onThread:dispatch_get_main_queue()];
          }
          onThread:kAPIEntitySyncerProcessNetworkResponseQueue];
         
         return nil;
     }];
    
    return requestDeferred.promise;
}

@end
