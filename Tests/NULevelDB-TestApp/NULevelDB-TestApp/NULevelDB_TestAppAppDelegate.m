//
//  NULevelDB_TestAppAppDelegate.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULevelDB_TestAppAppDelegate.h"

#import "NULevelDB_TestAppViewController.h"
#import <NULevelDB/NULDBDB.h>
#import "NULDBDB+Testing.h"
#import "NULDBTestUtilities.h"
#import "NULevelDBTester.h"
#import "NUCoreDataTester.h"

#import "NULDBTestCompany.h"
#import "NULDBTestAddress.h"
#import "NULDBTestPerson.h"


@interface NULDBDB (Tests)
- (void)runTests:(id)testDelegate;
@end


@interface NULevelDB_TestAppAppDelegate ()
- (void)runTests;
@end


@implementation NULevelDB_TestAppAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

+ (void)initialize {
    if([self class] == [NULevelDB_TestAppAppDelegate class]) {
        srandom(TEST_RANDOM_SEED);
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[NULevelDB_TestAppViewController alloc] initWithNibName:@"NULevelDB_TestAppViewController" bundle:nil]; 
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    [self performSelector:@selector(runTests) withObject:nil afterDelay:0];
    // This is a quick test to make sure we generate identical data regardless of which class hierarchy we're using
//    [self performSelector:@selector(runDataGenerationTest) withObject:nil afterDelay:0];
    
    return YES;
}

- (void)runDataGenerationTest {
    
    NULDBTestCompany *company = [NULDBTestCompany randomCompanyWithWorkers:1 managers:1 addresses:1];
    
    NSLog(@"Company: %@", [company plistRepresentation]);
}

- (void)runTests {
    
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *testPath = [docPath stringByAppendingPathComponent:@"test.storage"];
    // TODO add support for changing location of the test results database
//    NSString *resultsPath = [docPath stringByAppendingPathComponent:@"results.storage"];
    
    if([[NSFileManager defaultManager] removeItemAtPath:testPath error:NULL])
        NSLog(@"Deleted previous test db.");
    

    NULDBDB *db = [[NULDBDB alloc] initWithLocation:testPath];
    
#if 1
    NULevelDBTester *tester = [[NULevelDBTester alloc] init];
    
    tester.database = db;

    const int testCount = 1000;
    const int size = 256;

    NSUInteger tests[] = { 6, 7, 8 };

    for(NSUInteger i=0; i<sizeof(tests)/sizeof(NSUInteger); ++i) {
        switch (tests[i]) {
            case 0: [tester runPhoneTest:testCount];            break;
            case 1: [tester runAddressTest:testCount];          break;
            case 2: [tester runPersonTest:testCount];           break;
            case 3: [tester runCompanyTest:testCount];          break;
            case 4: [tester runBigTest:testCount];              break;
            case 5: [tester runFineGrainedTests:testCount];     break;
            case 6: [tester runValuesTest:testCount size:size]; break;
            case 7: [tester runDataTest:testCount size:size];   break;
            case 8: [tester runStringTest:testCount size:size]; break;
            default: break;
        }
    }
    
    NSLog(@"Results: %@", [tester resultsTableString]);
    
#else
    [db runTests:self];
#endif

    [NULDBDB destroyDatabase:testPath];
}

@end


typedef struct testResult {
    BOOL failed;
    NSUInteger count;
    NSUInteger loadCount;
    NSTimeInterval store;
    NSTimeInterval load;
    NSTimeInterval delete;
} TestResult;


@implementation NULDBDB (Tests)

// a^2 is the number of keys, b^2 is the size
// a counts up by powers of 2 and by counts down by powers of 2
- (void)testPowersOf2FromA:(NSUInteger)a toB:(NSUInteger)b lowerLimit:(NSUInteger)l {
    
    NSMutableArray *testData = [NSMutableArray array];
    NSDictionary *dict = nil;
    
    if(l < 1) l = 1;
    
    // Put tests
    while (b >= l) {
        [self put:2<<a valuesOfSize:2<<b data:&dict];
        [testData addObject:dict], dict = nil;
        a++, b--;
    }

    // Get tests
    for(NSDictionary *dict in testData) {
        [self getValuesForTestKeys:[dict allKeys]];
    }
    
    
    // Delete tests
    for(NSDictionary *dict in testData) {
        [self deleteValuesForTestKeys:[dict allKeys]];
    }
}

- (void)run4By8Tests {
    [self testPowersOf2FromA:4 toB:8 lowerLimit:1]; // 16 -> 256
}

- (void)run4By10Tests {
    [self testPowersOf2FromA:4 toB:10 lowerLimit:2]; // 16 -> 1024
}

- (void)run4By14Tests {
    [self testPowersOf2FromA:4 toB:14  lowerLimit:4]; // 16 -> 16384
}


#if TARGET_IPHONE_SIMULATOR
#define test_count 10000
#else
#define test_count 1000
#endif


- (BOOL)runBulkGenericTests:(TestResult *)testResult {
    
    NSTimeInterval start, end;
    NSDictionary *testData = randomTestDictionary(kGeneric, test_count);
    
    testResult->count = [testData count];
    
    start = [NSDate timeIntervalSinceReferenceDate];
    [self storeValuesFromDictionary:testData];
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->store = end - start;
    
    start = end;
    NSDictionary *copy = [self storedValuesForKeys:[testData allKeys]];
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->loadCount = [copy count];
    testResult->load = end-start;
    
    start = end;
    [self deleteStoredValuesForKeys:[testData allKeys]];
    testResult->delete = [NSDate timeIntervalSinceReferenceDate]-start;
    
    return YES;
}

- (BOOL)runBulkDataTests:(TestResult *)testResult {
    
    NSError *error = nil;
    NSTimeInterval start, end;
    NSDictionary *testData = randomTestDictionary(kData, test_count);
    
    testResult->count = [testData count];
    
    start = [NSDate timeIntervalSinceReferenceDate];
    if(![self storeDataFromDictionary:testData error:&error]) {
        NSLog(@"Error storing; %@", error);
        testResult->failed = YES;
        return NO;
    }
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->store = end - start;
    start = end;
    

    NSDictionary *copy = [self storedDataForKeys:[testData allKeys] error:&error];

    end = [NSDate timeIntervalSinceReferenceDate];
    if (nil == copy) {
        NSLog(@"Error loading; %@", error);
        testResult->failed = YES;
        return NO;
    }
    testResult->loadCount = [copy count];
    testResult->load = end - start;

    start = end;
    if(![self deleteStoredDataForKeys:[testData allKeys] error:&error]) {
        NSLog(@"Error deleting; %@", error);
        testResult->failed = YES;
        return NO;
    }
    testResult->delete = [NSDate timeIntervalSinceReferenceDate]-start;
    
    return YES;
}

- (BOOL)runBulkStringTests:(TestResult *)testResult {
    
    NSError *error = nil;
    NSTimeInterval start, end;
    NSDictionary *testData = randomTestDictionary(kString, test_count);
    
    testResult->count = [testData count];
    
    start = [NSDate timeIntervalSinceReferenceDate];
    if(![self storeStringsFromDictionary:testData error:&error]) {
        NSLog(@"Error storing; %@", error);
        testResult->failed = YES;
        return NO;
    }
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->store = end-start;    
    start = end;
    
    
    NSDictionary *copy = [self storedStringsForKeys:[testData allKeys] error:&error];
    
    if (nil == copy) {
        NSLog(@"Error loading; %@", error);
        testResult->failed = YES;
        return NO;
    }
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->loadCount = [copy count];
    testResult->load=end-start;
    
    start = end;
    if(![self deleteStoredStringsForKeys:[testData allKeys] error:&error]) {
        NSLog(@"Error deleting; %@", error);
        testResult->failed = YES;
        return NO;
    }
    testResult->delete = [NSDate timeIntervalSinceReferenceDate]-start;
    
    return YES;
}

- (BOOL)runBulkIndexTests:(TestResult *)testResult {
    
    NSError *error = nil;
    NSTimeInterval start, end;
    NSDictionary *testData = randomTestDictionary(kData, test_count);
    NSUInteger count = [testData count];
    
    uint64_t *indices = malloc(sizeof(uint64_t)*count);
    
    for(NSUInteger i=0; i<count; ++i) {
        indices[i] = (uint64_t)random() << 32 | i;
    }
    
    testResult->count = count;
    
    start = [NSDate timeIntervalSinceReferenceDate];
    if(![self storeDataFromArray:[testData allValues] forIndexes:indices error:&error]) {
        NSLog(@"Error storing for bulk indices: %@", error);
        testResult->failed = YES;
        return NO;
    }
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->store = end-start;
    
    start = end;
    NSArray *copy = [self storedDataForIndexes:indices count:count error:&error];
    if(nil == copy) {
        NSLog(@"Error loading for bulk indices;: %@", error);
        testResult->failed = YES;
        return NO;
    }
    end = [NSDate timeIntervalSinceReferenceDate];
    testResult->loadCount = [copy count];
    testResult->load = end-start;
    
    start = end;
    if(![self deleteStoredDataForIndexes:indices count:count error:&error]) {
        NSLog(@"Error deleting for bulk indices: %@", error);
        testResult->failed = YES;
        return NO;
    }
    testResult->delete = [NSDate timeIntervalSinceReferenceDate] - start;
    
    return YES;
}

- (void)runBulkOperationTests {
    
    TestResult testResult[4] = { {}, {}, {}, {} };
    
    NSLog(@"Starting bulk tests. Generic...");
        
    [self runBulkGenericTests:testResult];
    NSLog(@"...data...");
    [self runBulkDataTests:testResult+1];
    NSLog(@"...string...");
    [self runBulkStringTests:testResult+2];
    NSLog(@"...index...");
    [self runBulkIndexTests:testResult+3];
    
    TestResult result;
    
    NSArray *names = [NSArray arrayWithObjects:@"generic", @"data", @"string", @"index", nil];
    
    printf("\ntest results: Count   Store       per    Load  (count)       per  Delete     per\n\n");

    NSUInteger i=0;
    for(NSString *test in names) {
        result = testResult[i++];
        if(result.failed)
            printf(" %11s:  TEST FAILED", [test UTF8String]);
        else
            printf(" %11s: %5u %03.5f %01.7f %03.5f %7u  %01.7f %3.5f %01.7f\n",
                   [test UTF8String], result.count, result.store, result.store/result.count, result.load, result.loadCount, result.load/result.count, result.delete, result.delete/result.count);
    }
}

- (void)runTests:(id)testDelegate {
    
//    [self run4By8Tests];
    
//    [self run4By10Tests];
    
//    [self run4By14Tests];
        
//    [self runBulkOperationTests];
}

@end
