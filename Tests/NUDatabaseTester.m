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


NSString *kNUPhoneTestName = @"phone";
NSString *kNUAddressTestName = @"address";
NSString *kNUPersonTestName = @"person";
NSString *kNUCompanyTestName = @"company";
NSString *kNUBigCompanyTestName = @"big_company";

@interface NUDatabaseTester ()

+ (NUTestBlock)phoneTestBlock;
+ (NUTestBlock)addressTestBlock;
+ (NUTestBlock)personTestBlock;
+ (NUTestBlock)companyTestBlock;
+ (NUTestBlock)bigCompanyTestBlock;

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


@interface NUDatabaseTestRecord : NSObject<NSCoding> {
@public
    NSString *name;
    NSString *databaseClass;
    NSTimeInterval duration;
    NSUInteger databaseSize; // approximate
}
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *databaseClass;
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

@interface NUDatabaseTestAverage : NSObject {
@public
    NSString *name;
    NSString *databaseClass;
    NSTimeInterval totalDuration;
    NSUInteger count;
    NSUInteger databaseSize;
}
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *databaseClass;
@end

@implementation NUDatabaseTestAverage
@synthesize name, databaseClass;
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@ %u %u %0.4f (%0.4f)", self.databaseClass, self.name, databaseSize, count, totalDuration, totalDuration/count];
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
                      nil];
    }
    return self;
}

+ (NUTestBlock)phoneTestBlock {
    return [^(id database) {
        [database cycleObject:[NULDBTestPhone randomPhone]];
    } copy];
}

+ (NUTestBlock)addressTestBlock {
    return [^(id database) {
        [database cycleObject:[NULDBTestAddress randomAddress]];
    } copy];
}

+ (NUTestBlock)personTestBlock {
    return [^(id database) {
        [database cycleObject:[NULDBTestPerson randomPerson]];
    } copy];
}

+ (NUTestBlock)companyTestBlock {
    return [^(id database) {
        [database cycleObject:[NULDBTestCompany companyOf10]];
    } copy];
}

+ (NUTestBlock)bigCompanyTestBlock {
    return [^(id database) {
        [database cycleObject:[NULDBTestCompany companyOf100]];
    } copy];
}

- (NUTimedBlock)timerBlock {
    static NUTimedBlock timerBlock;
    static dispatch_once_t timerToken;
    dispatch_once(&timerToken, ^{
        timerBlock = [^(NUTestBlock block) {
            NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
            block(self.database);
            return [NSDate timeIntervalSinceReferenceDate] - start;
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

- (NSTimeInterval)runTestSet:(NSDictionary *)tests {
    
    NSTimeInterval totalTime = 0;
    NUTimedBlock timerBlock = [self timerBlock];
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    NSString *dbName = NSStringFromClass([self class]);
    
    for(NSString *name in [tests allKeys]) {
        
        NSUInteger count = [[tests objectForKey:name] unsignedIntegerValue];
        
        for(NSUInteger i=0; i<count; ++i) {

            NSTimeInterval time = timerBlock([self blockForTestName:name]);
            
            [results setObject:[[NUDatabaseTestRecord alloc] initWithName:name db:dbName duration:time size:0]
                        forKey:[NSDate date]];
            totalTime += time;
        }
        
        [resultsDB storeValuesFromDictionary:results];
    }

    return totalTime;
}

- (NSTimeInterval)runPhoneTest {
    return [self runTestSet:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:kNUPhoneTestName]];
}

- (NSTimeInterval)runAddressTest {
    return [self runTestSet:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:kNUAddressTestName]];
}

- (NSTimeInterval)runPersonTest {
    return [self runTestSet:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:kNUPersonTestName]];
}

- (NSTimeInterval)runCompanyTest {
    return [self runTestSet:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:kNUCompanyTestName]];
}

- (NSTimeInterval)runBigTest {
    return [self runTestSet:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:5] forKey:kNUBigCompanyTestName]];
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
