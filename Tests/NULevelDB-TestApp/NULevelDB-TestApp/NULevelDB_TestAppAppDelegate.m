//
//  NULevelDB_TestAppAppDelegate.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULevelDB_TestAppAppDelegate.h"

#import "NULevelDB_TestAppViewController.h"
#import "NULDBDB.h"
#import "NULDBDB+Testing.h"

#import "NULDBTestCompany.h"


@interface NULDBDB (Tests)
- (void)runTests;
@end


@interface NULevelDB_TestAppAppDelegate ()
- (void)runTests;
@end


@implementation NULevelDB_TestAppAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [[NULevelDB_TestAppViewController alloc] initWithNibName:@"NULevelDB_TestAppViewController" bundle:nil]; 
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    [self performSelector:@selector(runTests) withObject:nil afterDelay:0];
    
    return YES;
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
    
    NSString *testPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"test.storage"];
    NULDBDB *db = [[NULDBDB alloc] initWithLocation:testPath];
    
    [db runTests];
    [db destroy];
}

@end


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

- (void)runIterationTest {
    
    [self put:1000 valuesOfSize:1000 data:NULL];
    
    NSLog(@"Iterating over some values");
    
    NSDictionary *sample = [self storedValuesFromStart:@"0100" toLimit:@"0120"];
    
    NSLog(@"%@", sample);
}

- (void)runGraphTests {
    
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
    
    start = end;
    
    for(id key in [companies allKeys])
        [self storedObjectForKey:key];
    
    end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Finished loading. Took %0.4f seconds. Starting deleting.", end - start);
    
    for(id key in [companies allKeys])
        [self deleteStoredObjectForKey:key];
    
    end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Finished deleting. Took %0.4f seconds. Done testing", end - start);
}

- (void)runTests {
    
//    [self run4By8Tests];
    
//    [self run4By10Tests];
    
//    [self run4By14Tests];
    
    [self runGraphTests];
    
    
    NSLog(@"Testing finished");
}

@end
