#import "APIObject.h"
#import "KSDeferred.h"
#import "APICollection.h"
#import "APIObjectSubclass.h"
#import "APIEntitySyncer.h"
#import "APIHTTPClient.h"
#import <objc/runtime.h>

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;


SPEC_BEGIN(APIObjectSpec)

describe(@"APIObject", ^{
    __block APIObjectSubclass *subject;
    __block id<APIHTTPClient> httpClient;
    __block KSDeferred *requestDeferred;

    beforeEach(^{
        httpClient = nice_fake_for(@protocol(APIHTTPClient));
        [APIEntitySyncer setSharedHTTPClient:httpClient];
        requestDeferred = [KSDeferred defer];
        httpClient stub_method(@selector(makeRequestToEndpoint:withMethod:params:)).and_return(requestDeferred.promise);
        subject = [APIObjectSubclass new];
        subject.property1 = @"value";
        subject.property2 = @[@"array value"];
    });
    
    sharedExamplesFor(@"an APIObject rejection", ^(NSDictionary *) {
        __block KSPromise *syncPromise;
        __block APISyncableEntityState originalState;
        
        beforeEach(^{
            originalState = subject.syncState;
            syncPromise = [subject sync];
        });
        
        context(@"when the rejecting error's userInfo has an APIHTTPErrorMessageKey", ^{
            __block NSString *expectedMessage;
            
            beforeEach(^{
                expectedMessage = @"whyyyy? whyyyyyyy?";
                NSError *requestError = [NSError errorWithDomain:@"terrible error" code:100 userInfo:@{APIHTTPErrorMessageKey: expectedMessage}];
                [requestDeferred rejectWithError:requestError];
            });
            
            it(@"rejects with an error, using the message in the response as the description", ^{
                syncPromise.error.domain should equal(APIEntitySyncErrorDomain);
                syncPromise.error.code should equal(APIEntitySyncErrorCodeSyncFailure);
                syncPromise.error.localizedDescription should equal(expectedMessage);
            });
            
            it(@"does not change the state of the object", ^{
                expect(subject.syncState).to( equal(originalState) );
            });
        });
        
        context(@"when the rejecting error has no APIHTTPErrorMessageKey", ^{
            beforeEach(^{
                NSError *requestError = [NSError errorWithDomain:@"terrible error" code:100 userInfo:@{}];
                [requestDeferred rejectWithError:requestError];
            });
            
            it(@"rejects with an error, that has a generic description", ^{
                syncPromise.error.domain should equal(APIEntitySyncErrorDomain);
                syncPromise.error.code should equal(APIEntitySyncErrorCodeSyncFailure);
                syncPromise.error.localizedDescription should equal(@"An Error Occurred");
            });
            
            it(@"does not change the state of the object", ^{
                expect(subject.syncState).to( equal(originalState) );
            });
        });
    });
    
    describe(@"the object's resourcePath", ^{
        describe(@"when the object has no collection", ^{
            it(@"is the class resourcePath and the result of the evaluated resourceIdentifier", ^{
                subject.property1 = @"unique";
                expect(subject.resourcePath).to( equal(@"APIObjectSubclasses/unique") );
            });
        });
        
        describe(@"when the object has a collection", ^{
            it(@"is the collection resourcePath and the result of the evaluated resourceIdentifier", ^{
                APICollection *collection = [APICollection new];
                spy_on(collection);
                collection stub_method(@selector(resourcePath)).and_return(@"CollectionResourcePath");
                subject.property1 = @"unique";
                subject.collection = collection;
                
                subject.resourcePath should equal(@"CollectionResourcePath/unique");
            });
        });
        
        describe(@"when the object belongs to another object", ^{
            __block APIObject *owner;
            beforeEach(^{
                owner = [APIObject new];
                spy_on(owner);
                owner stub_method(@selector(resourcePath)).and_return(@"owners/1");
                subject.property1 = @"2";
                subject.object = owner;
            });
            
            it(@"is the object resourcePath and the result of the evaluated resourceIdentifier", ^{
                expect(subject.resourcePath).to( equal(@"owners/1/APIObjectSubclasses/2") );
            });
            
            context(@"and the object has no identifier", ^{
                it(@"does not append an identifier to the end", ^{
                    spy_on([APIObjectSubclass class]);
                    [APIObjectSubclass class] stub_method(@selector(resourceIdentifier)).and_return((SEL)NULL);
                    
                    subject.resourcePath should equal(@"owners/1/APIObjectSubclasses");
                });
            });
        });
    });
    
    describe(@"creating as existing", ^{
        beforeEach(^{
            subject = [APIObjectSubclass existing];
        });
        
        it(@"is in the synced state", ^{
            subject.syncState should equal(APISyncableEntityStateExisting);
        });
        
        it(@"stays in the synced state when a property is changed", ^{
            subject.property1 = @"BINGO";
            subject.syncState should equal(APISyncableEntityStateExisting);
        });
        
        describe(@"syncing", ^{
            beforeEach(^{
                subject.property1 = @"somethaang";
                subject.property2 = @[@"anotha thaang"];
                
                [subject sync];
            });
            
            it(@"calls the correct endpoint", ^{
                NSString *expectedEndpoint = @"APIObjectSubclasses/somethaang";
                httpClient should
                    have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                    .with(expectedEndpoint, Arguments::anything, Arguments::anything);
            });
            
            it(@"uses a GET request", ^{
                httpClient should
                    have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                    .with(Arguments::anything, APIHTTPMethodGET, Arguments::anything);
            });
            
            it(@"sends no params", ^{
                httpClient should
                    have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                    .with(Arguments::anything, Arguments::anything, nil);
            });
            
            describe(@"when the response is successful", ^{
                __block NSArray *originalProperty2Value;
                __block KSPromise *syncPromise;
                
                beforeEach(^{
                    originalProperty2Value = subject.property2;
                    NSDictionary *responseDictionary = @{[APIObjectSubclass resourceName]: @{
                                                                 @"network_property_1": @"different value",
                                                                 @"network_property_2": originalProperty2Value
                                                                 }
                                                         };
                    
                    syncPromise = [subject sync];
                    [requestDeferred resolveWithValue:responseDictionary];
                });
                
                it(@"sets the value to those returned by the server", ^{
                    expect(subject.property1).to( equal(@"different value") );
                    expect(subject.property2).to( equal(originalProperty2Value) );
                });
                
                it(@"sets the status to synced", ^{
                    expect(subject.syncState).to( equal(APISyncableEntityStateSynced) );
                });
                
                it(@"resolves the promise with the modified object", ^{
                    expect(syncPromise.value).to( be_same_instance_as(subject) );
                });
            });
            
            describe(@"when the response is not successful", ^{
                itShouldBehaveLike(@"an APIObject rejection");
            });
        });
    });
    
    describe(@"creating as new", ^{
        it(@"is in the new state", ^{
            subject.syncState should equal(APISyncableEntityStateNew);
        });
        
        it(@"stays in the new state when a value changes", ^{
            subject.property1 = @"dayyyyyyng";
            subject.syncState should equal(APISyncableEntityStateNew);
        });
        
        describe(@"syncing", ^{
            describe(@"the request made", ^{
                beforeEach(^{
                    subject.property1 = nil;
                    [subject sync];
                });
                
                it(@"calls the correct endpoint", ^{
                    NSString *expectedEndpoint = @"APIObjectSubclasses";
                    httpClient should
                        have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                        .with(expectedEndpoint, Arguments::anything, Arguments::anything);
                });
                
                it(@"makes a POST request", ^{
                    httpClient should
                        have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                        .with(Arguments::anything, APIHTTPMethodPOST, Arguments::anything);
                });
                
                it(@"sends a dictionary of API parameters mapped to value", ^{
                    NSDictionary *expectedParams = @{
                                                     @"network_property_2": subject.property2
                                                     };
                   
                    
                    httpClient should
                        have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                        .with(Arguments::anything, Arguments::anything, expectedParams);
                });
            });
            
            describe(@"when the response is successful", ^{
                __block NSArray *originalProperty2Value;
                __block KSPromise *syncPromise;
                beforeEach(^{
                    originalProperty2Value = subject.property2;
                    NSDictionary *responseDictionary = @{[APIObjectSubclass resourceName]: @{
                                                                 @"network_property_1": @"different value",
                                                                 @"network_property_2": originalProperty2Value
                                                                 }
                                                         };
                    syncPromise = [subject sync];
                    
                    [requestDeferred resolveWithValue:responseDictionary];
                });
                
                it(@"sets the value to those returned by the server", ^{
                    expect(subject.property1).to( equal(@"different value") );
                    expect(subject.property2).to( equal(originalProperty2Value) );
                });
                
                it(@"sets the status to synced", ^{
                    expect(subject.syncState).to( equal(APISyncableEntityStateSynced) );
                });
                
                it(@"resolves the promise with the modified object", ^{
                    expect(syncPromise.value).to( be_same_instance_as(subject) );
                });
                
                it(@"a subsequent call to sync does not make a network request", ^{
                    [(id<CedarDouble>)httpClient reset_sent_messages];
                    
                    subject.save.value should be_same_instance_as(subject);
                    httpClient should_not have_received(@selector(makeRequestToEndpoint:withMethod:params:));
                });
            });
            
            describe(@"when the response is not successful", ^{
                itShouldBehaveLike(@"an APIObject rejection");
            });
        });
    });
    
    describe(@"destroying an object", ^{
        __block APICollection *collection;
        
        beforeEach(^{
            subject.property1 = @"32";
            
            collection = [APICollection new];
            spy_on(collection);
            collection stub_method(@selector(resourcePath)).and_return(@"collection_resources");
            [collection addObject:subject];
            
            [subject destroy];
        });
        
        describe(@"the request made", ^{
            it(@"calls the correct endpoint", ^{
                NSString *expectedEndpoint = @"collection_resources/32";

                httpClient should
                    have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                    .with(expectedEndpoint, Arguments::anything, Arguments::anything);
            });
            
            it(@"makes a POST request", ^{
                httpClient should
                    have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                    .with(Arguments::anything, APIHTTPMethodDELETE, Arguments::anything);
            });
            
            it(@"sends a dictionary of API parameters mapped to value", ^{
                httpClient should
                    have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                    .with(Arguments::anything, Arguments::anything, nil);
            });
        });
        
        describe(@"when the request succeeds", ^{
            it(@"removes itself from its collection on success", ^{
                [requestDeferred resolveWithValue:nil];
                collection.objects should_not contain(subject);
            });
        });
        
        describe(@"when the request fails", ^{
            it(@"remains in its collection on failure", ^{
                [requestDeferred rejectWithError:[NSError errorWithDomain:@"" code:1 userInfo:nil]];
                collection.objects should contain(subject);
            });
 
            itShouldBehaveLike(@"an APIObject rejection");
        });
    });
    
    describe(@"APIObject state", ^{
        context(@"when in synced state and a parameter is changed", ^{
            beforeEach(^{
                subject.state = APISyncableEntityStateSynced;
                subject.property1 = @"new value mayne";
            });
            
            it(@"changes the state to dirty", ^{
                subject.syncState should equal(APISyncableEntityStateDirty);
            });
        });
    });

    describe(@"serialization", ^{
        it(@"encodes the properties in the objectToNetworkKeyMap", ^{
            NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:subject];
            APIObjectSubclass *unarchivedApiObject = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];

            unarchivedApiObject.property1 should equal(subject.property1);
            unarchivedApiObject.property2 should equal(subject.property2);
        });
    });
    
    describe(@"parsing JSON", ^{
        describe(@"without a pre-exiting instance", ^{
            it(@"creates a new object with the expected properties", ^{
                subject = [APIObjectSubclass fromJSON:@{
                                                        @"network_property_1": @"property1",
                                                        @"network_property_2": @[]
                                                        }];
                
                subject.syncState should equal(APISyncableEntityStateSynced);
                subject.property1 should equal(@"property1");
                subject.property2 should equal(@[]);
            });
            
            it(@"converts '<null>' entries into nil", ^{
                subject = [APIObjectSubclass fromJSON:@{
                                                        @"network_property_1": @"property1",
                                                        @"network_property_2": [NSNull null]
                                                        }];
                
                subject.syncState should equal(APISyncableEntityStateSynced);
                subject.property1 should equal(@"property1");
                subject.property2 should be_nil;
            });
        });
        
        describe(@"with a pre-existing instance", ^{
            it(@"merges in the new properties", ^{
                [(id<APISyncableEntity>)subject setState:APISyncableEntityStateDirty];
                [subject parse:@{@"network_property_1": @"new value"}];
                expect(subject.property1).to( equal(@"new value") );
                expect(subject.property2).to( equal(@[@"array value"]) );
                expect(subject.syncState).to( equal(APISyncableEntityStateSynced) );
            });
        });
        
        describe(@"getting an identifier from JSON", ^{
            it(@"returns the identifier from the given JSON", ^{
                NSString *identifier = [APIObjectSubclass identifierFromJSON:@{@"network_property_1": @"property1", @"network_property_2": @[]}];
                identifier should equal(@"property1");
            });
        });
    });
    
    describe(@"-toJSON", ^{
        beforeEach(^{
            subject = [APIObjectSubclass new];
            subject.property1 = @"property1";
            subject.property2 = @[];
        });
        
        describe(@"when there are no network value methods", ^{
            it(@"returns a dictionary of the values", ^{
                subject.toJSON should equal(@{
                                              @"network_property_1": @"property1",
                                              @"network_property_2": @[]
                                              });
            });
        });
        
        describe(@"when there are network value methods", ^{
            beforeEach(^{
                IMP property1NetworkValueIMP = imp_implementationWithBlock(^(APIObjectSubclass *me){
                    return @"property1NetworkValue";
                });
                
                class_addMethod([APIObjectSubclass class], NSSelectorFromString(@"property1NetworkValue"), property1NetworkValueIMP, "@@:");
            });
            
            afterEach(^{
                IMP property1NetworkValueIMP = imp_implementationWithBlock(^(APIObjectSubclass *me){
                    return me.property1;
                });
                
                class_replaceMethod([APIObjectSubclass class], NSSelectorFromString(@"property1NetworkValue"), property1NetworkValueIMP, "@@:");
            });
            
            it(@"uses the network value", ^{
                subject.toJSON should equal(@{
                                              @"network_property_1": @"property1NetworkValue",
                                              @"network_property_2": @[]
                                              });
            });
        });
    });
});

SPEC_END
