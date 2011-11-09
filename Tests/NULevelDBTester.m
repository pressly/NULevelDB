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


NSString *kNUStoreValuesTestName = @"store_values";
NSString *kNULoadValuesTestName = @"load_values";
NSString *kNUDeleteValuesTestName = @"delete_values";


@interface NULevelDBTester ()
+ (NUTestBlock)storeValuesBlock;
+ (NUTestBlock)loadValuesBlock;
+ (NUTestBlock)deleteValuesBlock;
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
        [self addBlock:[[self class] storeValuesBlock] forTestName:kNUStoreValuesTestName];
        [self addBlock:[[self class] loadValuesBlock] forTestName:kNULoadValuesTestName];
        [self addBlock:[[self class] deleteValuesBlock] forTestName:kNUDeleteValuesTestName];
    }
    
    return self;
}

+ (NUTestBlock)storeValuesBlock {
    return [^(NULDBDB *database, NUDatabaseTestSet *set) {
        NSDictionary *dict = [set.testData objectForKey:@"data"];
        for(id key in [dict allKeys]) [database storeValue:[dict objectForKey:key] forKey:key];
    } copy];
}

+ (NUTestBlock)loadValuesBlock {
    return [^(NULDBDB *database, NUDatabaseTestSet *set) {
        NSDictionary *dict = [set.testData objectForKey:@"data"];
        for(id key in [dict allKeys]) [database storedValueForKey:key];
    } copy];
}

+ (NUTestBlock)deleteValuesBlock {
    return [^(NULDBDB *database, NUDatabaseTestSet *set) {
        NSDictionary *dict = [set.testData objectForKey:@"data"];
        for(id key in [dict allKeys]) [database deleteStoredValueForKey:key];        
    } copy];
}

- (void)runValuesTest:(NSUInteger)count size:(NSUInteger)size {

    NSString *name = [@"values " stringByAppendingFormat:@"%u", size];
    NSArray *tests = [NSArray arrayWithObjects:kNUStoreValuesTestName, kNULoadValuesTestName, kNUDeleteValuesTestName, nil];
    NUDatabaseTestSet *set = [NUDatabaseTestSet testSetWithName:name testNames:tests count:count];
    int width = (int)log10((double)count) + 1;
    
    for (NSUInteger i=0; i<count; ++i)
        [set.testData setObject:randomString(size) forKey:[NSString stringWithFormat:@"%0*d", width, i]];
    
    [self runTestSet:set];
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
