//
//  NULevelDBTester.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NULevelDBTester.h"

#import "NULDBTestCompany.h"
#import "NULDBTestUtilities.h"

#import <NULevelDB/NULDBDB.h>


NSString *kNUBasicStoreTestName  = @"basic STOR";
NSString *kNUBasicLoadTestName   = @"basic LOAD";
NSString *kNUBasicDeleteTestName = @"basic DEL";


@interface NULevelDBTester ()
+ (NSDictionary *)valueOperationBlocks;
+ (NSDictionary *)dataOperationBlocks;
+ (NSDictionary *)stringOperationBlocks;
+ (NUTestBlock)wrapperBlock;
@end


@implementation NULevelDBTester

- (void)setDatabase:(id)aDB {
    NSParameterAssert([aDB isKindOfClass:[NULDBDB class]]);
    if(aDB != database)
        database = aDB;
}

- (id)database {
    return database;
}

- (id)init {
    self = [super init];
    if(self) {
        [self addBlock:[[self class] wrapperBlock] forTestName:kNUBasicStoreTestName];
        [self addBlock:[[self class] wrapperBlock] forTestName:kNUBasicLoadTestName];
        [self addBlock:[[self class] wrapperBlock] forTestName:kNUBasicDeleteTestName];
    }
    
    return self;
}

+ (NSDictionary *)valueOperationBlocks {
    static NSDictionary *blocks;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NUDatabaseOperationBlock store = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            [database storeValue:[data objectForKey:key] forKey:key];
        };
        NUDatabaseOperationBlock load = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            id result = [database storedValueForKey:key];
            NSAssert(nil != result, @"Found no (value) entry for key %@ in database", key);
        };
        NUDatabaseOperationBlock del = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            [database deleteStoredValueForKey:key];
        };
        blocks = [NSDictionary dictionaryWithObjectsAndKeys:
                  [store copy], kNUBasicStoreTestName,
                  [load copy],  kNUBasicLoadTestName,
                  [del copy],   kNUBasicDeleteTestName,
                  nil];
    });
    return blocks;
}

+ (NSDictionary *)dataOperationBlocks {
    static NSDictionary *blocks;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NUDatabaseOperationBlock store = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            [database storeData:[data objectForKey:key] forKey:key error:NULL];
        };
        NUDatabaseOperationBlock load = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            id result = [database storedDataForKey:key error:NULL];
            NSAssert(nil != result, @"Found no (data) entry for key %@ in database", key);
        };
        NUDatabaseOperationBlock del = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            [database deleteStoredDataForKey:key error:NULL];
        };
        blocks = [NSDictionary dictionaryWithObjectsAndKeys:
                  [store copy], kNUBasicStoreTestName,
                  [load copy],  kNUBasicLoadTestName,
                  [del copy],   kNUBasicDeleteTestName,
                  nil];
    });
    return blocks;
}

+ (NSDictionary *)stringOperationBlocks {
    static NSDictionary *blocks;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NUDatabaseOperationBlock store = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            [database storeString:[data objectForKey:key] forKey:key error:NULL];
        };
        NUDatabaseOperationBlock load = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            id result = [database storedStringForKey:key error:NULL];
            NSAssert(nil != result, @"Found no (string) entry for key %@ in database", key);
        };
        NUDatabaseOperationBlock del = ^(NULDBDB *database, NSDictionary *data, NSString *key) {
            [database deleteStoredDataForKey:key error:NULL];
        };
        blocks = [NSDictionary dictionaryWithObjectsAndKeys:
                  [store copy], kNUBasicStoreTestName,
                  [load copy],  kNUBasicLoadTestName,
                  [del copy],   kNUBasicDeleteTestName,
                  nil];
    });
    return blocks;
}

// The wrapper block takes care of unpacking the test data and iterating over the storage keys
// It invokes the block for the current operation block (store, load, delete) with the current arguments
// The operation blocks perform the store, load or delete appropriate to the current test variant (value, data, string)
+ (NUTestBlock)wrapperBlock {
    return [^(NULDBDB *database, NUDatabaseTestSet *set) {
        NSDictionary *dict = [set.testData objectForKey:@"data"];
        NUDatabaseOperationBlock block = [[set.testData objectForKey:@"operations"] objectForKey:set.currentTest];
        for(NSString *key in [dict allKeys]) block(database, dict, key);
    } copy];
}

- (void)testDataType:(TestDataType)type operations:(NSDictionary *)operations count:(NSUInteger)count size:(NSUInteger)size {
    
    NSString *name = [NSString stringWithFormat:@"%@ %u", nameForType(type), size];
    NSArray *testNames = [[NSArray alloc] initWithObjects:kNUBasicStoreTestName, kNUBasicLoadTestName, kNUBasicDeleteTestName, nil];
    NUDatabaseTestSet *set = [NUDatabaseTestSet testSetWithName:name testNames:testNames count:count];
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:count];
    int width = (int)log10((double)count) + 1; // make the keys just long enough to fit the largest value
    
    for (NSUInteger i=0; i<count; ++i)
        [data setObject:randomTestValue(type, size) forKey:[[NSString alloc] initWithFormat:@"%0*d", width, i]];
    
    [set.testData setObject:data forKey:@"data"];
    [set.testData setObject:operations forKey:@"operations"];
    
    [self runTestSet:set];
}

- (void)runValuesTest:(NSUInteger)count size:(NSUInteger)size {
    [self testDataType:kGeneric operations:[[self class] valueOperationBlocks] count:count size:size];
}

- (void)runDataTest:(NSUInteger)count size:(NSUInteger)size {
    [self testDataType:kData operations:[[self class] dataOperationBlocks] count:count size:size];
}

- (void)runStringTest:(NSUInteger)count size:(NSUInteger)size {
    [self testDataType:kString operations:[[self class] stringOperationBlocks] count:count size:size];
}

@end

@implementation NULDBDB (NUTestDatabase)

- (void)saveObjects:(NSArray *)objects {
    for(id<NULDBSerializable>object in objects)
        [self storeObject:object];
}

- (NSDictionary *)loadObjects:(NSArray *)keysORIDs {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[keysORIDs count]];
    
    for(NSString *key in keysORIDs)
        [dict setObject:[self storedObjectForKey:key] forKey:key];
    
    return [dict copy];
}

- (void)deleteObjects:(NSArray *)keysOrIDs {
    for(NSString *key in keysOrIDs)
        [self deleteStoredObjectForKey:key];
}

@end
