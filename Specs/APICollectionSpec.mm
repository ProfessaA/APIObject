#import "APICollection.h"
#import "KSDeferred.h"
#import "APIObjectSubclass.h"
#import "APIEntitySyncer.h"
#import "APIObjectParser.h"
#import "APICollectionParser.h"
#import "APIHTTPClient.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

@interface APICollectionSubclass : APICollection

@end

@implementation APICollectionSubclass

+ (Class)objectClass
{
    return [APIObjectSubclass class];
}

- (NSString *)resourceName
{
    return @"api_object_subclasses";
}

@end

@interface APIObjectWithCollection : APIObject

@property (nonatomic, strong) APICollectionSubclass *myCollection;

@end

@implementation APIObjectWithCollection

+ (NSString *)resourceName
{
    return @"object_with_collection";
}

+ (NSDictionary *)objectToNetworkKeyMap
{
    return @{
             @"myCollection": @"network_collection"
             };
}

@end

SPEC_BEGIN(APICollectionSpec)

describe(@"APICollection", ^{
    __block APICollectionSubclass *subject;
    __block id<APIHTTPClient> httpClient;

    beforeEach(^{
        httpClient = nice_fake_for(@protocol(APIHTTPClient));
        [APIEntitySyncer setSharedHTTPClient:httpClient];
        subject = [APICollectionSubclass new];
    });
    
    describe(@"the collection's resource path", ^{
        describe(@"when the collection has no +resourcePath specified", ^{
            describe(@"when the collection has no owner", ^{
                it(@"is the collection resource path", ^{
                    expect(subject.resourcePath).to( equal([APIObjectSubclass resourcePath]) );
                });
            });
            
            describe(@"when the collection has an owner", ^{
                it(@"is the owner resource path with the collection resource path appended", ^{
                    APIObjectSubclass *owner = [APIObjectSubclass new];
                    owner.property1 = @"8";
                    subject = [[APICollectionSubclass alloc] initWithOwner:owner];
                    
                    expect(subject.resourcePath).to( equal(@"APIObjectSubclasses/8/APIObjectSubclasses") );
                });
            });
        });
        
        describe(@"when the collection has a +resourcePath specified", ^{
            beforeEach(^{
                spy_on([APICollectionSubclass class]);
                [APICollectionSubclass class] stub_method(@selector(resourcePath)).and_return(@"collection_path");
            });
            
            describe(@"when the collection has no owner", ^{
                it(@"is the collection resource path", ^{
                    expect(subject.resourcePath).to( equal(@"collection_path") );
                });
            });
            
            describe(@"when the collection has an owner", ^{
                it(@"is the owner resource path with the collection resource path appended", ^{
                    APIObjectSubclass *owner = [APIObjectSubclass new];
                    owner.property1 = @"8";
                    subject = [[APICollectionSubclass alloc] initWithOwner:owner];
                    
                    expect(subject.resourcePath).to( equal(@"APIObjectSubclasses/8/collection_path") );
                });
            });
        });
    });
    
    describe(@"building an object", ^{
        it(@"creates a new object of the given class", ^{
            APIObjectSubclass *builtObject = [subject buildObject];
            
            expect(builtObject).to( be_instance_of([APIObjectSubclass class]) );
            expect(subject.objects).to( contain(builtObject) );
        });
    });
    
    describe(@"syncing", ^{
        __block APIObjectSubclass *firstObject;
        __block APIObjectSubclass *secondObject;
        __block KSDeferred *syncDeferred;
        
        beforeEach(^{
            firstObject = [subject buildObject];
            firstObject.property1 = @"first_prop1";
            firstObject.property2 = @[@"first_prop2"];
            
            secondObject = [subject buildObject];
            secondObject.property1 = @"second_prop1";
            secondObject.property2 = @[@"second_prop2"];
            
            syncDeferred = [KSDeferred defer];
            httpClient stub_method(@selector(makeRequestToEndpoint:withMethod:params:)).and_return(syncDeferred.promise);
            
            [subject sync];
        });
        
        it(@"makes a request with the correct http method", ^{
            httpClient should
                have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                .with(Arguments::anything, APIHTTPMethodPOST, Arguments::anything);
        });
        
        it(@"sends the correct parameters", ^{
            NSDictionary *expectedParams = @{
                                             @"api_object_subclasses": @[
                                                     @{@"network_property_1": @"first_prop1", @"network_property_2": @[@"first_prop2"]},
                                                     @{@"network_property_1": @"second_prop1", @"network_property_2": @[@"second_prop2"]}
                                                     ]
                                             };
            
            httpClient should
                have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                .with(Arguments::anything, Arguments::anything, expectedParams);

        });
        
        it(@"hits the appropriate endpoint", ^{
            NSString *expectedEndpoint = @"APIObjectSubclasses";
            
            httpClient should
                have_received(@selector(makeRequestToEndpoint:withMethod:params:))
                .with(expectedEndpoint, Arguments::anything, Arguments::anything);
        });
        
        describe(@"on success", ^{
            beforeEach(^{
                NSDictionary *responseDictionary = @{
                                                     @"api_object_subclasses": @[
                                                             @{@"network_property_1": @"first_network_prop1", @"network_property_2": @[@"first_network_prop2"]},
                                                             @{@"network_property_1": @"second_network_prop1", @"network_property_2": @[@"second_network_prop2"]}
                                                             ]
                                                     };
                
                [syncDeferred resolveWithValue:responseDictionary];
            });
            
            it(@"uses the response to create objects with the given properties", ^{
                expect(subject.objects.count).to( equal(2) );
                
                APIObjectSubclass *firstObject = [subject objectWithIdentifier:@"first_network_prop1"];
                expect(firstObject).to( be_instance_of([APIObjectSubclass class]) );
                expect(firstObject.property1).to( equal(@"first_network_prop1") );
                expect(firstObject.property2).to( equal(@[@"first_network_prop2"]) );

                APIObjectSubclass *secondObject = [subject objectWithIdentifier:@"second_network_prop1"];
                expect(secondObject).to( be_instance_of([APIObjectSubclass class]) );
                expect(secondObject.property1).to( equal(@"second_network_prop1") );
                expect(secondObject.property2).to( equal(@[@"second_network_prop2"]) );
                
                expect([(id<APISyncableEntity>)subject state]).to( equal(APISyncableEntityStateSynced) );
            });
        });
        
        describe(@"on failure", ^{
            beforeEach(^{
                NSError *syncError = [NSError errorWithDomain:APIEntitySyncErrorDomain code:APIEntitySyncErrorCodeSyncFailure userInfo:@{APIHTTPErrorMessageKey: @"it don't work..."}];
                [syncDeferred rejectWithError:syncError];
            });
            
            it(@"doesn't change the state of the collection", ^{
                expect([(id<APISyncableEntity>)subject state]).to( equal(APISyncableEntityStateNew) );
            });
            
            it(@"doesn't modify the objects in the collection", ^{
                expect(subject.objects.firstObject).to( be_same_instance_as(firstObject) );
                expect(subject.objects.lastObject).to( be_same_instance_as(secondObject) );
            });
        });
    });
    
    describe(@"parsing json", ^{
        __block APIObjectSubclass *existingInstance;
        __block APIObjectSubclass *instanceToDelete;
        beforeEach(^{
            existingInstance = [subject buildObject];
            existingInstance.property1 = @"1";
            existingInstance.property2 = @[];
            
            instanceToDelete = [subject buildObject];
            instanceToDelete.property1 = @"99";
            
            [subject parse:@[@{@"network_property_1": @"1", @"network_property_2": @[@"changed"]},
                             @{@"network_property_1": @"2", @"network_property_2": @[@"new"]}]];
        });
        
        it(@"modifies existing objects in place", ^{
            expect([subject objectWithIdentifier:@"1"]).to( be_same_instance_as(existingInstance));
            expect(existingInstance.property2).to( equal(@[@"changed"]) );
            expect(existingInstance.collection).to( be_same_instance_as(subject) );
        });
        
        it(@"adds new objects", ^{
            APIObjectSubclass *newInstance = [subject objectWithIdentifier:@"2"];
            expect(newInstance.property2).to( equal(@[@"new"]) );
            expect(newInstance.collection).to( be_same_instance_as(subject) );
        });
        
        it(@"removes objects not in the response", ^{
            subject.objects should_not contain(instanceToDelete);
        });
        
        it(@"respects the servers order over the client order", ^{
            [subject parse:@[@{@"network_property_1": @"2", @"network_property_2": @[@"new"]},
                             @{@"network_property_1": @"1", @"network_property_2": @[@"changed"]}]];
            
            [subject.objects.firstObject property1] should equal(@"2");
            [subject.objects.lastObject property1] should equal(@"1");
        });
    });
    
    describe(@"querying the collection", ^{
        describe(@"for an object with a particular identifier", ^{
            it(@"returns an object with resourceIdentifier matching the given object", ^{
                APIObjectSubclass *first = [subject buildObject];
                first.property1 = @"first";
                
                APIObjectSubclass *second = [subject buildObject];
                second.property1 = @"second";
                
                [subject objectWithIdentifier:@"first"];
            });
        });
        
        describe(@"for objects in a particular state", ^{
            __block APIObjectSubclass *syncedObject;
            __block APIObjectSubclass *dirtyObject;
            
            beforeEach(^{
                syncedObject = [subject buildObject];
                spy_on(syncedObject);
                syncedObject stub_method(@selector(state)).and_return(APISyncableEntityStateSynced);
                
                dirtyObject = [subject buildObject];
                spy_on(dirtyObject);
                dirtyObject stub_method(@selector(state)).and_return(APISyncableEntityStateDirty);
            });
            
            it(@"returns objects in the given state", ^{
                [subject objectsInState:APISyncableEntityStateSynced].firstObject should be_same_instance_as(syncedObject);
                [subject objectsInState:APISyncableEntityStateDirty].firstObject should be_same_instance_as(dirtyObject);
                [subject objectsInState:APISyncableEntityStateExisting] should be_empty;
            });
        });
    });
    
    describe(@"an APIObject with a collection", ^{
        __block APIObjectWithCollection *object;
        beforeEach(^{
            object = [APIObjectWithCollection new];
            object.myCollection = subject;
        });
        
        it(@"parses incoming JSON properly", ^{
            [object parse:@{
                            @"network_collection": @[@{@"network_property_1": @"yo", @"network_property_2": @[@"yo"]}]
                            }];
            [[subject objectWithIdentifier:@"yo"] property2] should equal(@[@"yo"]);
        });
        
        it(@"creates outgoing JSON properly", ^{
            APIObjectSubclass *builtObject = [subject buildObject];
            builtObject.property1 = @"yup";
            
            NSDictionary *objectJSON = [[(id<APISyncableEntity>)object parser] objectToNetworkDictionary];
            NSDictionary *expectedDictionary = @{@"network_collection": [(id<APISyncableEntity>)subject toJSON]};
            objectJSON should equal(expectedDictionary);
        });
        
        it(@"encodes and decodes correctly", ^{
            NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:object];
            APIObjectWithCollection *unarchivedObject = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
            unarchivedObject.myCollection.object should be_same_instance_as(unarchivedObject);
        });
    });
    
    describe(@"encoding and decoding", ^{
        beforeEach(^{
            APIObjectSubclass *firstObject = [subject buildObject];
            firstObject.property1 = @"one";
            firstObject.property2 = @[@"one"];
            
            APIObjectSubclass *secondObject = [subject buildObject];
            secondObject.property1 = @"two";
            secondObject.property2 = @[@"two"];
        });
        
        it(@"is encoded and decoded properly", ^{
            NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:subject];
            APICollectionSubclass *unarchivedAPICollection = [NSKeyedUnarchiver unarchiveObjectWithData:archiveData];
            
            [[unarchivedAPICollection objectWithIdentifier:@"one"] property2] should equal(@[@"one"]);
            [[unarchivedAPICollection objectWithIdentifier:@"one"] collection] should be_same_instance_as(unarchivedAPICollection);
            
            [[unarchivedAPICollection objectWithIdentifier:@"two"] property2] should equal(@[@"two"]);
            [[unarchivedAPICollection objectWithIdentifier:@"two"] collection] should be_same_instance_as(unarchivedAPICollection);
        });
    });
});

SPEC_END
