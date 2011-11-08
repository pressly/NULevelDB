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

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)runTests {
    
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *testPath = [docPath stringByAppendingPathComponent:@"test.storage"];
    // TODO add support for changing location of the test results database
//    NSString *resultsPath = [docPath stringByAppendingPathComponent:@"results.storage"];
    
    if([[NSFileManager defaultManager] removeItemAtPath:testPath error:NULL])
        NSLog(@"Deleted previous test db");
    

    NULDBDB *db = [[NULDBDB alloc] initWithLocation:testPath];
    
#if 1
    NUDatabaseTester *tester = [[NULevelDBTester alloc] init];
    
    tester.database = db;
    
    [tester runBigTest];
    NSLog(@"Results: %@", [tester resultsTableString]);
    
#else
    [db runTests:self];
    [db destroy];
#endif
}

@end


@implementation NULDBDB (Tests)

- (NSData *)makeTestData {
    
    static NSData *data;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        NSError *error = nil;
        data = [NSPropertyListSerialization dataWithPropertyList:[[NULDBTestAddress randomAddress] plistRepresentation]
                                                          format:NSPropertyListBinaryFormat_v1_0
                                                         options:0
                                                           error:&error];
        if(nil == data)
            NSLog(@"Failed to make data; %@", error);
    });
    
    return data;
}

enum {
    kGeneric,
    kData,
    kString
};

#if TARGET_IPHONE_SIMULATOR
#define test_count 10000
#else
#define test_count 1000
#endif

- (NSDictionary *)makeTestDictionary:(unsigned)type {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:test_count];
    
    for(int i = 0; i<test_count; ++i) {
        
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

typedef struct testResult {
    BOOL failed;
    NSUInteger count;
    NSUInteger loadCount;
    NSTimeInterval store;
    NSTimeInterval load;
    NSTimeInterval delete;
} TestResult;


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

- (void)runIterationTest {
    
    [self put:1000 valuesOfSize:1000 data:NULL];
    
    NSLog(@"Iterating over some values");
    
    NSDictionary *sample = [self storedValuesFrom:@"0100" to:@"0120"];
    
    NSLog(@"%@", sample);
}

- (void)runGraphTests:(id)testDelegate {
    
    NSMutableDictionary *companies = [NSMutableDictionary dictionary];
    
    for(int i=0; i<5; ++i) {
        
        NULDBTestCompany *company = [NULDBTestCompany companyOf100];
        
        [companies setObject:company forKey:company.name];
    }
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    NSLog(@"Starting graph serialization test");
    
    for(id key in [companies allKeys])
        [self storeObject:[companies objectForKey:key]];

    NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];

    NSLog(@"Finished storing. Took %0.4f seconds. Starting loading.", end - start);
        
    NSMutableArray *companiesArray = [NSMutableArray array];
    
    start = [NSDate timeIntervalSinceReferenceDate];
    for(id key in [companies allKeys])
        [companiesArray addObject:[self storedObjectForKey:key]];
    
    end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Finished loading. Took %0.4f seconds. Starting deleting.", end - start);

    
//    NSArray *sort = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];

//    for(NULDBTestCompany *company in [companiesArray sortedArrayUsingDescriptors:sort]) {
//        NSLog(@"Workers for company %@:\n%@", company.name, [[[[company.workers valueForKey:@"fullName"] allObjects] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]);
//        NSLog(@"Addresses for company %@:\n%@", company.name, [[[[company.addresses valueForKey:@"description"] allObjects] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"\n"]);
//    }
    
    start = [NSDate timeIntervalSinceReferenceDate];

    for(id key in [companies allKeys])
        [self deleteStoredObjectForKey:key];
    
    end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Finished deleting. Took %0.4f seconds. Done testing", end - start);
}

- (BOOL)runBulkGenericTests:(TestResult *)testResult {
    
    NSTimeInterval start, end;
    NSDictionary *testData = [self makeTestDictionary:kGeneric];
    
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
    NSDictionary *testData = [self makeTestDictionary:kData];
    
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
    NSDictionary *testData = [self makeTestDictionary:kString];
    
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
    NSDictionary *testData = [self makeTestDictionary:kData];
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
    
    [self runGraphTests:(id)testDelegate];
    
//    [self runBulkOperationTests];
    
    NSLog(@"Testing finished");
}

@end
