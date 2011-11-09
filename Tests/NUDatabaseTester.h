//
//  NUDatabaseTester.h
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NULDBTestModel.h"


@class NULDBDB;

// Included tests
extern NSString *kNUPhoneTestName;
extern NSString *kNUAddressTestName; 
extern NSString *kNUPersonTestName;
extern NSString *kNUCompanyTestName;
extern NSString *kNUBigCompanyTestName;
extern NSString *kNUWriteTestName; 
extern NSString *kNUReadTestName;
extern NSString *kNUDeleteTestName;

@interface NSObject (NUTestDatabase)
- (void)saveObjects:(NSArray *)objects;
- (NSDictionary *)loadObjects:(NSArray *)keysORIDs;
- (void)deleteObjects:(NSArray *)keysOrIDs;
@end

@interface NULDBTestModel (NUTestObject)
- (id)uniqueIdentifier;
@end


@interface NUDatabaseTestSet : NSObject {
@private
    NSString *name;
    NSArray *testNames;
    NSMutableDictionary *testData;
@public
    NSUInteger count;
}
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray *testNames;
@property (nonatomic, strong)id testData;

+ (NUDatabaseTestSet *)testSetWithName:(NSString *)name testNames:(NSArray *)testNames count:(NSUInteger)count;
@end


@interface NUDatabaseTestRecord : NSObject<NSCoding> {
@private
    NSString *name;
    NSString *databaseClass;
@public
    NSTimeInterval duration;
    NSUInteger databaseSize; // approximate
}
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *databaseClass;
@end


@interface NUDatabaseTestAverage : NSObject {
@private
    NSString *name;
    NSString *databaseClass;
@public
    NSTimeInterval totalDuration;
    NSUInteger databaseSize;
    NSUInteger count;
}
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *databaseClass;
@end


typedef void (^NUTestBlock)(id database, NUDatabaseTestSet *testSet);
typedef NSTimeInterval (^NUTimedBlock)(NUTestBlock block, NUDatabaseTestSet *testSet);

@interface NUDatabaseTester : NSObject {
    NULDBDB *resultsDB;
    NSMutableDictionary *testBlocks;
    BOOL reopen;
}

@property (nonatomic, retain) id database;
@property (nonatomic, readonly) NUTimedBlock timerBlock;

// these methods maintain a directory of test blocks for repeated use
// (they don't run any tests)
- (NUTestBlock)blockForTestName:(NSString *)name;
- (void)addBlock:(NUTestBlock)block forTestName:(NSString *)name;

// tests is an array of NUDatabaseTestSet objects
- (NSTimeInterval)runTestSets:(NSArray *)tests;
- (NSTimeInterval)runTestSet:(NUDatabaseTestSet *)set;

- (NSTimeInterval)runPhoneTest:(NSUInteger)count;
- (NSTimeInterval)runAddressTest:(NSUInteger)count;
- (NSTimeInterval)runPersonTest:(NSUInteger)count;
- (NSTimeInterval)runCompanyTest:(NSUInteger)count;
- (NSTimeInterval)runBigTest:(NSUInteger)count;

// does count writes, reads, and then deletes, measuring each step seperately
- (NSTimeInterval)runFineGrainedTests:(NSUInteger)count;

- (NSDictionary *)allResults;

- (NSString *)resultsTableString;

@end
