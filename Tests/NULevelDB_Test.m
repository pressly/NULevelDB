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
#import "NULDBTestUtilities.h"


// It's annoying when long-running tests run every time you try to build your test
#define TESTING_NEW_TEST 0


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
        data = [[NSPropertyListSerialization dataWithPropertyList:[[self makeTestAddress] plistRepresentation]
                                                           format:NSPropertyListBinaryFormat_v1_0
                                                          options:0
                                                            error:&error] retain];
                
        STAssertNotNil(data, @"Failed to make data. %@", error);
    });
    
    return data;
}

enum {
    kGeneric,
    kData,
    kString
};

- (NSDictionary *)makeTestDictionary:(unsigned)type count:(NSUInteger)count {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
        
    for(int i = 0; i<count; ++i) {
        
        NULDBTestPerson *person = [NULDBTestPerson randomPerson];
        NSDictionary *plist = [person plistRepresentation];
        NSData *plistData = nil;
        id key = [person uniqueID];
        id value;
        
        if(type > 0) {
            int plistType = NSPropertyListBinaryFormat_v1_0;
            if(type > 1)
                plistType = NSPropertyListXMLFormat_v1_0;
            plistData = [NSPropertyListSerialization dataWithPropertyList:plist format:plistType options:0 error:NULL];
        }
        
        switch (type) {
                
            case kString:
                value = [[NSString alloc] initWithData:plistData encoding:NSUTF8StringEncoding];
                break;
                
            case kData:
                value = plistData;
                key = [key dataUsingEncoding:NSUTF8StringEncoding];
                break;
                
            case kGeneric:
            default:
                value = plist;
                break;
        }

        [dict setObject:value forKey:key];
    }
    
    return [NSDictionary dictionaryWithDictionary:dict];
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

#if ! TESTING_NEW_TEST
- (void)test07GenericBulk {
    
    NSDictionary *dict = [self makeTestDictionary:kGeneric count:1000];
    
    STAssertTrue([db storeValuesFromDictionary:dict], @"Failed to bulk store generic values");
    
    NSDictionary *actual = [db storedValuesForKeys:[dict allKeys]];
    
    STAssertEqualObjects(dict, actual, @"Failed to bulk load generic values (non-matching)");
    
    STAssertTrue([db deleteStoredValuesForKeys:[dict allKeys]], @"Failed to bulk delete generic values");
}

- (void)test08DataBulk {
    
    NSError *error = nil;
    NSDictionary *dict = [self makeTestDictionary:kData count:1000];
    
    STAssertTrue([db storeDataFromDictionary:dict error:&error], @"Failed to bulk store data; %@", error);
    
    NSDictionary *actual = [db storedDataForKeys:[dict allKeys] error:&error];
    
    STAssertEqualObjects(actual, dict, @"Failed to bulk load data values (non-matching); %@", error);
    
    STAssertTrue([db deleteStoredDataForKeys:[dict allKeys] error:&error], @"Failed to bulk delete data values; %@", error);
}

- (void)test09StringBulk {
    
    NSError *error = nil;
    NSDictionary *dict = [self makeTestDictionary:kString count:1000];
    
    STAssertTrue([db storeStringsFromDictionary:dict error:&error], @"Failed to bulk store strings; %@", error);
    
    NSDictionary *actual = [db storedStringsForKeys:[dict allKeys] error:&error];
    
    STAssertEqualObjects(actual, dict, @"Failed to bulk load data values (non-matching); %@", error);
    
    STAssertTrue([db deleteStoredStringsForKeys:[dict allKeys] error:&error], @"Failed to bulk delete data values; %@", error);
}
#endif

#if ! TESTING_NEW_TEST
- (void)test10IndexBulk {
    
    NSError *error = nil;
    NSArray *expected = [[self makeTestDictionary:kData count:1000] allValues];
    NSUInteger count = [expected count];
    uint64_t *indices = malloc(sizeof(uint64_t) * count);
    uint64_t *sortIndices = indices;
    
    NSAssert(NULL != indices, @"Malloc failure");
    
    for(NSUInteger i=0; i<count; ++i) {
        indices[i] = (uint64_t)random() << 32 | i;
    }
    
    if(count <= 10) {
        for(NSUInteger i=0; i<count; ++i)
            NSLog(@"index %u: %llx", i, indices[i]);
    }
    
    NSComparator comp = ^(id obj1, id obj2) {
        uint64_t i1 = sortIndices[[expected indexOfObject:obj1]], i2 = sortIndices[[expected indexOfObject:obj2]];
        if(i1 < i2)
            return -1;
        if(i1 > i2)
            return 1;
        return 0;
    };
    
    expected = [expected sortedArrayUsingComparator:comp];
    
    STAssertTrue([db storeDataFromArray:expected forIndexes:indices error:&error], @"Failed to bulk store indexed values; %@", error);
    
    // shuffle the indexes
    uint64_t *indices_copy = malloc(sizeof(uint64_t) * count);
    
    memcpy(indices_copy, indices, count*sizeof(uint64_t));

    for(NSUInteger i=0; i<count; ++i) {
        NSUInteger left = Random_int_in_range(0, count-1), right = Random_int_in_range(0, count-1);
        if(left == right)
            continue;
        uint64_t temp = indices_copy[left];  indices_copy[left] = indices_copy[right]; indices_copy[right] = temp;
    }
    
    if(count <= 10) {
        for(NSUInteger i=0; i<count; ++i)
            NSLog(@"copied shuffled index %u: %llx", i, indices_copy[i]);
    }
    
    sortIndices = indices_copy;
    
    NSArray *actual = [[db storedDataForIndexes:indices_copy count:count error:&error] sortedArrayUsingComparator:comp];
    
    STAssertEqualObjects(expected, actual, @"Failed to bulk load indexed values (objects don't match)");
    
    STAssertTrue([db deleteStoredDataForIndexes:indices_copy count:count error:&error], @"Failed to bulk delete indexed values; %@", error);
}
#endif

#if ! TESTING_NEW_TEST
- (void)test20KeyedArchiveSerialization {
    
    NULDBTestPhone *e = [[NULDBTestPhone alloc] initWithAreaCode:416 exchange:967 line:1111];
    NSString *key = @"phone_1";
    
    [db storeValue:e forKey:key];
    
    id a = [db storedObjectForKey:key];
    
    STAssertTrue([e isEqual:a], @"Stored value discrepancy. Expected: %@; actual: %@.", e, a);
}

- (void)test21PlistSerialization {
    
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

- (void)test22GraphSerialization {
    
    NULDBTestCompany *company = [NULDBTestCompany randomSizedCompany];
    
    [db storeObject:company];
    
    NULDBTestCompany *a = [db storedObjectForKey:[company storageKey]];
    
    NSLog(@"%@", a);
}
#endif

- (void)test30Iteration {
    
    NSUInteger count = 10;
    NSDictionary *dict = [self makeTestDictionary:kString count:count];
    NSMutableDictionary *temp = [NSMutableDictionary dictionary];
    
    NSUInteger i = 0;
    for(NSString *key in [dict allKeys]) {
        [temp setObject:[dict objectForKey:key] forKey:[NSString stringWithFormat:@"KEY%010u", i += (unsigned)Random_int_in_range(1, 4)]];
    }
    
    dict = temp;
    
    [db storeValuesFromDictionary:dict];
    
    NSArray *keys = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger i1 = count/3, i2 = 3*count/4;
    NSUInteger retrievedCount = i2-i1;
    NSString *key1 = [keys objectAtIndex:i1], *key2 = [keys objectAtIndex:i2];
    
    NSDictionary *actual = [db storedValuesFrom:key1 to:key2];
    
    STAssertTrue([actual count] == retrievedCount, @"Missing values; expected %u; got %u", retrievedCount, [actual count]);
}

- (void)test31EnumerateAll {
    
    NSMutableDictionary *expected = [NSMutableDictionary dictionaryWithCapacity:32];
    
    for(NSUInteger i=0; i<32; ++i)
        [expected setObject:NULDBRandomName() forKey:[NSNumber numberWithInt:Random_int_in_range(i*32, i*32+32)]];
    
    for(id number in [expected allKeys]) {
        NSError *error = nil;
        BOOL success = [db storeData:[NSKeyedArchiver archivedDataWithRootObject:[expected objectForKey:number]]
                          forDataKey:[NSKeyedArchiver archivedDataWithRootObject:number] error:&error];
        STAssertTrue(success, @"DB store failed for key '%@'; error: %@", number, error);
    }
    
    
    NSMutableDictionary *actual = [NSMutableDictionary dictionaryWithCapacity:[expected count]];
    
    [db enumerateAllEntriesWithBlock:^BOOL(NSData *key, NSData *value) {
        [actual setObject:[NSKeyedUnarchiver unarchiveObjectWithData:value]
                   forKey:[NSKeyedUnarchiver unarchiveObjectWithData:key]];
        return YES;
    }];
    
    STAssertEqualObjects(expected, actual, @"Enumeration discrepancy");
}

- (void)test40EntryExistence {
    
    [db storeValue:@"EncodedValue" forKey:@"EncodedKey"];
    
    STAssertTrue([db storedValueExistsForKey:@"EncodedKey"], @"Entry existence discrepancy; key 'Key' should exist.");
    STAssertFalse([db storedValueExistsForKey:@"UnusedKey"], @"Entry existence discrepancy; key 'UnusedKey' should NOT exist.");

    
    NSData *dataKey = [@"DataKeyForData" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *unusedDataKey = [@"UnusedDataKeyForData" dataUsingEncoding:NSUTF8StringEncoding];
    
    [db storeData:[@"DataValueForData" dataUsingEncoding:NSUTF8StringEncoding] forDataKey:dataKey error:NULL];
    
    STAssertTrue([db storedDataExistsForDataKey:dataKey], @"Entry existence discrepancy; key '%@' should exist.", dataKey);
    STAssertFalse([db storedDataExistsForDataKey:unusedDataKey], @"Entry existence discrepancy; key '%@' should NOT exist", unusedDataKey);
    
    NSString *stringKey = @"StringKeyForData";
    NSString *unusedStringKey = @"UnusedStringKeyForData";
    
    [db storeData:[@"DataValueForString" dataUsingEncoding:NSUTF8StringEncoding] forKey:stringKey error:NULL];
    
    STAssertTrue([db storedDataExistsForKey:stringKey], @"key '%@' should exist.", stringKey);
    STAssertFalse([db storedDataExistsForKey:unusedStringKey], @"key '%@' should NOT exist.", unusedStringKey);
    
    stringKey = @"StringKeyForStringValue";
    unusedStringKey = @"UnusedStringKeyForStringValue";
    
    [db storeString:@"StringValue" forKey:stringKey error:NULL];
    STAssertTrue([db storedDataExistsForKey:stringKey], @"key '%@' should exist.", stringKey);
    STAssertFalse([db storedDataExistsForKey:unusedStringKey], @"key '%@' should NOT exist.", unusedStringKey);

    uint64_t indexKey = 1234567;
    uint64_t unusedIndexKey = 123456789;
    
    [db storeData:[@"DataValueForIndex" dataUsingEncoding:NSUTF8StringEncoding] forIndexKey:indexKey error:NULL];
    
    STAssertTrue([db storedDataExistsForIndexKey:indexKey], @"key '%d' should exist.", indexKey);
    STAssertFalse([db storedDataExistsForIndexKey:unusedIndexKey], @"key '%d' should NOT exist.", unusedIndexKey);
}

@end
