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


@interface NSObject (NUTestDatabase)
- (void)saveObjects:(NSArray *)objects;
- (NSDictionary *)loadObjects:(NSArray *)keysORIDs;
- (void)deleteObjects:(NSArray *)keysOrIDs;
@end

@interface NULDBTestModel (NUTestObject)
- (id)uniqueIdentifier;
@end

typedef void (^NUTestBlock)(id database);
typedef NSTimeInterval (^NUTimedBlock)(NUTestBlock block);

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

// A test set is a dictionary of test names (keys) and times to run them (numbers)
- (NSTimeInterval)runTestSet:(NSDictionary *)tests;

- (NSTimeInterval)runPhoneTest;
- (NSTimeInterval)runAddressTest;
- (NSTimeInterval)runPersonTest;
- (NSTimeInterval)runCompanyTest;
- (NSTimeInterval)runBigTest;

- (NSDictionary *)allResults;

- (NSString *)resultsTableString;

@end
