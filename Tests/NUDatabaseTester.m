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


@implementation NUDatabaseTester

@dynamic database;

- (id)init {
    self = [super init];
    if(self) {
        resultsDB = [[NULDBDB alloc] init];
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
    
    for(NSString *name in [tests allKeys]) {
        
        NSUInteger count = [[tests objectForKey:name] unsignedIntegerValue];
        
        for(NSUInteger i=0; i<count; ++i) {

            NSTimeInterval time = timerBlock([self blockForTestName:name]);
            
            [results setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithDouble:time], @"time",
                                name, @"name",
                                NSStringFromClass([self class]), @"database",
                                nil]
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