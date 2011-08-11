//
//  NULevelDB_Test.m
//  NULevelDB-Test
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULevelDB_Test.h"

#import "NULDBDB.h"
#import "NULDBDB+Testing.h"

#import "NULDBTestPhone.h"
#import "NULDBTestPerson.h"
#import "NULDBTestAddress.h"
#import "NULDBTestCompany.h"


static NSString *bigString = @"Erlang looks weird to the uninitiated, so I'll step it through for you. On the line numbered (1), we define an array with four numbers as elements, and calls the function lists:for_each with that list as a first argument, and a block taking one argument as the second argument (just as the function Enumerable#each takes a block argument in the Ruby example above). The block begins at the -> and goes on until the last end. All that first block does is it spawns a new Erlang process (line (2)), again taking a block as an argument to do the actual test, but now THIS block (line (2) still) is executing concurrently, and thus the test on line (3) is done concurrently for all elements in the array.";


@interface NULDBWrapper : NSObject<NULDBSerializable>
@property (retain) NSString *identifier;
@property (retain) id object;
@end

@implementation NULDBWrapper

@synthesize identifier, object;

- (NSArray *)propertyNames {
    return [NSArray arrayWithObject:@"object"];
}

- (NSString *)storageKey {
    return identifier;
}

- (id)initWithObject:(id)obj identifier:(NSString *)ident {
    self.object = obj;
    self.identifier = ident;
    return self;
}

@end


@interface NULevelDB_Test ()

@property (retain) NULDBDB *db;

@end


@implementation NULevelDB_Test

@synthesize db;

+ (void)initialize {
    [NULDBDB enableLogging];
}

- (void)setUp
{
    [super setUp];
    
    db = [[NULDBDB alloc] init];
}

- (void)tearDown
{
    [db destroy];
    [super tearDown];
}

- (NULDBTestAddress *)makeTestAddress {
    
    static NULDBTestAddress *address;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        address = [[NULDBTestAddress alloc] init];
        
        address.street = @"100 Avenue Road";
        address.city = @"Toronto";
        address.state = @"Ontario";
        address.postalCode = @"M4T 9G3";
    });
    
    return address;
}

- (NSData *)makeTestData {
    
    static NSData *data;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        NSError *error = nil;
        data = [NSPropertyListSerialization dataWithPropertyList:[[self makeTestAddress] plistRepresentation]
                                                          format:NSPropertyListBinaryFormat_v1_0
                                                         options:0
                                                           error:&error];
        
        STAssertNotNil(data, @"Failed to make data. %@", error);
    });
    
    return data;
}

- (void)verifyAddressFromData:(NSData *)value error:(NSError *)error {
    
    STAssertEqualObjects(value, [self makeTestData], @"Test data does not match; expected: %@; actual: %@", [self makeTestData], value);
    
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:value
                                                                    options:0
                                                                     format:NULL
                                                                      error:&error];
    
    STAssertNotNil(plist, @"Could not read plist for value (%@); %@", value, error);
    
    NULDBTestAddress *expected = [self makeTestAddress];
    NULDBTestAddress *actual = [[NULDBTestAddress alloc] initWithPropertyList:plist];
    
    STAssertNotNil(actual, @"Failed make address with plist");
    STAssertEqualObjects(actual, expected, @"Loaded data does not match! Expected: %@; Actual: %@", actual, expected);
}



- (void)test01Example
{
    id e = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithFloat:3.0f*93-13.0f/4], @"number",
                    @"STRING", @"string",
                    [NSArray arrayWithObjects:@"1", @"2", @"3", nil], @"array",
                    nil];
    
    [db storeValue:e forKey:@"dictionary"];
    
    id a = [db storedValueForKey:@"dictionary"];
    STAssertTrue([e isEqual:a], @"Stored value not equal on retrieval. Expected %@; actual: %@", e, a);
}

- (void)test02DataKeys {

    NSError *error = nil;
    struct test {
        int foo;
        double bar;
        char baz[8];
    } test;
    
    strncpy(test.baz, "my data", 7);
    
    NSData *key = [NSData dataWithBytes:&test length:sizeof(struct test)];
    
    STAssertTrue([db storeData:[self makeTestData] forDataKey:key error:&error], @"Failed to store data for key (%@): %@", key, error);
    
    [self verifyAddressFromData:[db storedDataForDataKey:key error:&error] error:error];
    
    STAssertTrue([db deleteStoredDataForDataKey:key error:&error], @"Failed to delete data for key (%@); %@", key, error);
}

- (void)test03StringKeys {
 
    NSError *error = nil;
    NSString *key = @"TEST_STRING";
    
    STAssertTrue([db storeData:[self makeTestData] forKey:key error:&error], @"Failed to store data for key (%@); %@", key, error);
    
    [self verifyAddressFromData:[db storedDataForKey:key error:&error] error:error];
    
    STAssertTrue([db deleteStoredDataForKey:key error:&error], @"Failed to delete data for key (%@); %@", key, error);
}

- (void)test04IndexKeys {
    
    NSError *error = nil;
    uint64_t index = (uint64_t)random() << 32|random();
    
    STAssertTrue([db storeData:[self makeTestData] forIndexKey:index error:&error], @"Failed to store data for key %llu; %@", index, error);
    
    [self verifyAddressFromData:[db storedDataForIndexKey:index error:&error] error:error];
    
    STAssertTrue([db deleteStoredDataForIndexKey:index error:&error], @"Failed to delete data for key (%llu); %@", index, error);
}


- (void)test05KeyConversion {
    
    NSError *error = nil;
    
    NSData *(^block)(NSString *) = ^ (NSString *string) {
        return [NSData dataWithBytes:"hello" length:5];
    };
        
    STAssertTrue([db storeData:[self makeTestData] forKey:nil translator:block error:&error], @"Failed to store data for converted key; %@", error);
    
    [self verifyAddressFromData:[db storedDataForKey:nil translator:block error:&error] error:error];
    
    STAssertTrue([db deleteStoredDataForKey:nil translator:block error:&error], @"Failed to delete data for key (%@); %@", error);
}

- (void)test06StringValues {
    
    NSError *error = nil;
    NSString *key = @"TEST_KEY";
    
    STAssertTrue([db storeString:bigString forKey:key error:&error], @"Failed to store big string for key (%@); %@", key, error);
    
    NSString *actual = [db storedStringForKey:key error:&error];
    
    STAssertEqualObjects(actual, bigString, @"Failed to retrieve string for key (%@); %@", key, error);
    
    STAssertTrue([db deleteStoredDataForKey:key error:&error], @"Failed to delete big string for key (%@); %@", key, error);
}

// These performance tests aren't very interesting in relation to iOS
//- (void)testPut10By1000 {
//    [db put:10 valuesOfSize:1000 data:NULL];
//}
//
//- (void)testPut100By100 {
//    [db put:100 valuesOfSize:100 data:NULL];
//}
//
//- (void)testPut1000By10 {
//    [db put:1000 valuesOfSize:10 data:NULL];
//}

- (void)test10KeyedArchiveSerialization {
    
    NULDBTestPhone *e = [[NULDBTestPhone alloc] initWithAreaCode:416 exchange:967 line:1111];
    NSString *key = @"phone_1";
    
    [db storeValue:e forKey:key];
    
    id a = [db storedObjectForKey:key];
    
    STAssertTrue([e isEqual:a], @"Stored value discrepancy. Expected: %@; actual: %@.", e, a);
}

- (void)test11PlistSerialization {
    
    NULDBTestAddress *address = [self makeTestAddress];
    NULDBWrapper *e = [[NULDBWrapper alloc] initWithObject:address identifier:address.uniqueID];
    
    [db storeObject:e];
    
    
    id wrapper = [db storedObjectForKey:address.uniqueID];
    
    STAssertTrue([wrapper isKindOfClass:[NULDBWrapper class]], @"Wrapper class fail; got %@", wrapper);
    
    id a = [wrapper object];
    
    STAssertTrue([a isKindOfClass:[NULDBTestAddress class]], @"Wrapped object fail; got %@", a);
    
    [a setUniqueID:address.uniqueID];
    
    STAssertTrue([address isEqual:a], @"Stored value discrepancy. Expected: %@; actual: %@.", e, a);
}

- (void)test12GraphSerialization {
    
    NULDBTestCompany *company = [NULDBTestCompany randomSizedCompany];
    
    [db storeObject:company];
    
    NULDBTestCompany *a = [db storedObjectForKey:[company storageKey]];
    
    NSLog(@"%@", a);
}

@end
