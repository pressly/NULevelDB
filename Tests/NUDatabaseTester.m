//
//  NUDatabaseTester.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NUDatabaseTester.h"

#import "NULDBTestCompany.h"
#import "NULDBTestAddress.h"
#import "NULDBTestPerson.h"
#import "NULDBTestPhone.h"

#import <NULevelDB/NULDBDB.h>


#if STRICT_RELATIONAL
NSString *kNUPhoneTestName = @"phone (relational)";
NSString *kNUAddressTestName = @"address (relational)";
NSString *kNUPersonTestName = @"person (relational)";
NSString *kNUCompanyTestName = @"company (relational)";
NSString *kNUBigCompanyTestName = @"big_company (relational)";
NSString *kNUWriteTestName = @"write (relational)";
NSString *kNUReadTestName = @"read (relational)";
NSString *kNUDeleteTestName = @"delete (relational)";

#else
NSString *kNUPhoneTestName = @"phone";
NSString *kNUAddressTestName = @"address";
NSString *kNUPersonTestName = @"person";
NSString *kNUCompanyTestName = @"company";
NSString *kNUBigCompanyTestName = @"big_company";
NSString *kNUWriteTestName = @"write";
NSString *kNUReadTestName = @"read";
NSString *kNUDeleteTestName = @"delete";
#endif

@interface NUDatabaseTester ()

+ (NUTestBlock)phoneTestBlock;
+ (NUTestBlock)addressTestBlock;
+ (NUTestBlock)personTestBlock;
+ (NUTestBlock)companyTestBlock;
+ (NUTestBlock)bigCompanyTestBlock;
+ (NUTestBlock)writeTestBlock;
+ (NUTestBlock)readTestBlock;
+ (NUTestBlock)verifyReadTestBlock;
+ (NUTestBlock)deleteTestBlock;

- (NUTimedBlock)timerBlock;

@end


@implementation NSObject (NUTestDatabaseConveniences)

- (void)cycleObjects:(NSArray *)objects {
    NSArray *ids = [objects valueForKey:@"uniqueIdentifier"];
    [self saveObjects:objects];
    [self loadObjects:ids];
    [self deleteObjects:ids];
}

- (void)cycleObject:(id)object {
    [self cycleObjects:[NSArray arrayWithObject:object]];
}

@end


@implementation NUDatabaseTestSet
@synthesize name, currentTest, testNames, testData;

- (id)init {
    self = [super init];
    if(self)
        self.testData = [NSMutableDictionary dictionary];
    return self;
}

+ (NUDatabaseTestSet *)testSetWithName:(NSString *)name testNames:(NSArray *)testNames count:(NSUInteger)count {
    
    NUDatabaseTestSet *set = [[self alloc] init];
    
    set.name = name;
    set.testNames = testNames;
    set->count = count;
    
    return set;
}

@end


@implementation NUDatabaseTestRecord
@synthesize name, databaseClass;
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.name forKey:@"1"];
    [aCoder encodeObject:self.databaseClass forKey:@"2"];
    [aCoder encodeFloat:duration forKey:@"3"];
    [aCoder encodeInteger:databaseSize forKey:@"4"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if(self) {
        self.name = [aDecoder decodeObjectForKey:@"1"];
        self.databaseClass = [aDecoder decodeObjectForKey:@"2"];
        duration = [aDecoder decodeFloatForKey:@"3"];
        databaseSize = [aDecoder decodeIntegerForKey:@"4"];
    }
    
    return self;
}

- (id)initWithName:(NSString *)n db:(NSString *)db duration:(NSTimeInterval)dur size:(NSUInteger)size {
    self = [super init];
    if(self) {
        self.name = n;
        self.databaseClass = db;
        duration = dur;
        databaseSize = size;
    }
    return self;
}

@end


@implementation NUDatabaseTestAverage
@synthesize name, databaseClass;
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %u %0.4f (%0.7f)", self.databaseClass, count, totalDuration, totalDuration/count];
}

- (id)initWithRecord:(NUDatabaseTestRecord *)record {
    self = [super init];
    if(self) {
        self.name = record.name;
        self.databaseClass = record.databaseClass;
        totalDuration = record->duration;
        databaseSize = record->databaseSize;
        count = 1;
    }
    return self;
}

- (void)addRecord:(NUDatabaseTestRecord *)record {
    totalDuration += record->duration;
    ++count;
}
@end


@implementation NUDatabaseTester

@dynamic database;

- (id)init {
    self = [super init];
    if(self) {
        NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *location = [docsPath stringByAppendingPathComponent:@"testResults.storage"];
        resultsDB = [[NULDBDB alloc] initWithLocation:location];
        testBlocks = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                      [[self class] phoneTestBlock], kNUPhoneTestName,
                      [[self class] addressTestBlock], kNUAddressTestName,
                      [[self class] personTestBlock], kNUPersonTestName,
                      [[self class] companyTestBlock], kNUCompanyTestName,
                      [[self class] bigCompanyTestBlock], kNUBigCompanyTestName,
                      [[self class] writeTestBlock], kNUWriteTestName,
                      [[self class] readTestBlock], kNUReadTestName,
                      [[self class] verifyReadTestBlock], @"verify_read",
                      [[self class] deleteTestBlock], kNUDeleteTestName,
                      nil];
    }
    return self;
}

+ (NUTestBlock)phoneTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        [database cycleObject:[NULDBTestPhone randomPhone]];
    } copy];
}

+ (NUTestBlock)addressTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        [database cycleObject:[NULDBTestAddress randomAddress]];
    } copy];
}

+ (NUTestBlock)personTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        [database cycleObject:[NULDBTestPerson randomPerson]];
    } copy];
}

+ (NUTestBlock)companyTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        [database cycleObject:[NULDBTestCompany companyOf10]];
    } copy];
}

+ (NUTestBlock)bigCompanyTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
#if TARGET_IPHONE_SIMULATOR
        [database cycleObject:[NULDBTestCompany companyOf1000]];
#else
        [database cycleObject:[NULDBTestCompany companyOf100]];
#endif
    } copy];
}

+ (NUTestBlock)writeTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
#if TARGET_IPHONE_SIMULATOR
        NULDBTestCompany *co = [NULDBTestCompany companyOf1000];
#else
        NULDBTestCompany *co = [NULDBTestCompany companyOf100];
#endif
        [database saveObjects:[NSArray arrayWithObject:co]];
        [testSet.testData setObject:[co storageKey] forKey:@"storage_key"];
    } copy];
}

+ (NUTestBlock)readTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        NSString *key = [testSet.testData objectForKey:@"storage_key"];
        NSDictionary *results = [database loadObjects:[NSArray arrayWithObject:key]];
        assert([results count] > 0);
        [testSet.testData setObject:results forKey:@"read_results"];
    } copy];
}

+ (NUTestBlock)verifyReadTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        NSDictionary *results = [testSet.testData objectForKey:@"read_results"];
        NSLog(@"read data: %@", results);
    } copy];
}

+ (NUTestBlock)deleteTestBlock {
    return [^(id database, NUDatabaseTestSet *testSet) {
        NSString *key = [testSet.testData objectForKey:@"storage_key"];
        [database deleteObjects:[NSArray arrayWithObject:key]];
    } copy];
}

- (NUTimedBlock)timerBlock {
    static NUTimedBlock timerBlock;
    static dispatch_once_t timerToken;
    dispatch_once(&timerToken, ^{
        timerBlock = [^(NUTestBlock block, NUDatabaseTestSet *testSet) {
            @autoreleasepool {
                NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
                block(self.database, testSet);
                return [NSDate timeIntervalSinceReferenceDate] - start;
            }
        } copy];
    });
    return timerBlock;
}

- (NUTestBlock)blockForTestName:(NSString *)name {
    return [testBlocks objectForKey:name];
}

- (void)addBlock:(NUTestBlock)block forTestName:(NSString *)name {
    [testBlocks setObject:[block copy] forKey:name];
}

- (NSTimeInterval)runTestSets:(NSArray *)tests {
    
    NSTimeInterval totalTime = 0;
    NUTimedBlock timerBlock = [self timerBlock];
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    NSString *dbName = NSStringFromClass([self class]);
    
    for(NUDatabaseTestSet *set in tests) {
        
        NSLog(@"Running test '%@' %u times...", set.name, set->count);
        
        for(NSUInteger i=0; i<set->count; ++i) {
            for(NSString *testName in set.testNames) {
        
                set.currentTest = testName;
                
                NSTimeInterval time = timerBlock([self blockForTestName:testName], set);
                NSString *recordName = [[NSString alloc] initWithFormat:@"%@ - %@", set.name, testName];
                
                [results setObject:[[NUDatabaseTestRecord alloc] initWithName:recordName db:dbName duration:time size:0]
                            forKey:[[NSDate alloc] init]];
                totalTime += time;
            }
        }
        
        NSLog(@"...finished (%0.7f seconds).", totalTime);
    }
    
    [resultsDB storeValuesFromDictionary:results];
    
    return totalTime;
}

- (NSTimeInterval)runTestSet:(NUDatabaseTestSet *)set {
    return [self runTestSets:[NSArray arrayWithObject:set]];
}

- (NSTimeInterval)runPhoneTest:(NSUInteger)count {
    return [self runTestSet:[NUDatabaseTestSet testSetWithName:@"r/w/d phone"
                                                     testNames:[NSArray arrayWithObject:kNUPhoneTestName]
                                                         count:count]];
}

- (NSTimeInterval)runAddressTest:(NSUInteger)count {
    return [self runTestSet:[NUDatabaseTestSet testSetWithName:@"r/w/d address"
                                                     testNames:[NSArray arrayWithObject:kNUAddressTestName]
                                                         count:count]];
}

- (NSTimeInterval)runPersonTest:(NSUInteger)count {
    return [self runTestSet:[NUDatabaseTestSet testSetWithName:@"r/w/d person"
                                                     testNames:[NSArray arrayWithObject:kNUPersonTestName]
                                                         count:count]];
}

- (NSTimeInterval)runCompanyTest:(NSUInteger)count {
    return [self runTestSet:[NUDatabaseTestSet testSetWithName:@"r/w/d company"
                                                     testNames:[NSArray arrayWithObject:kNUCompanyTestName]
                                                         count:count]];
}

- (NSTimeInterval)runBigTest:(NSUInteger)count {
    return [self runTestSet:[NUDatabaseTestSet testSetWithName:@"big test"
                                                     testNames:[NSArray arrayWithObject:kNUBigCompanyTestName]
                                                         count:count]];
}

- (NSTimeInterval)runFineGrainedTests:(NSUInteger)count {
    
    NSArray *testNames = [NSArray arrayWithObjects:kNUWriteTestName, kNUReadTestName, kNUDeleteTestName, nil];
    
    return [self runTestSet:[NUDatabaseTestSet testSetWithName:@"fine grained r/w/d companies" testNames:testNames count:count]];
}

- (NSDictionary *)allResults {
    
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    [resultsDB enumerateFrom:nil to:nil block:^BOOL(NSDate *key, NUDatabaseTestRecord *record) {
       
        NUDatabaseTestAverage *average = [results objectForKey:record.name];
        
        if(nil == average) {
            average = [[NUDatabaseTestAverage alloc] initWithRecord:record];
            [results setObject:average forKey:record.name];
        }
        else
            [average addRecord:record];
        
        return YES;
    }];
    
    return [results copy];
}

- (NSString *)resultsTableString {
    
    NSDictionary *results = [self allResults];
    
    // TODO: log the device
    
    return [results description];
}

@end

@implementation NULDBTestModel (NUTestObject)

- (id)uniqueIdentifier {
#if NULDBTEST_CORE_DATA
    return [self objectID];
#else
    return [self storageKey];
#endif
}

@end
