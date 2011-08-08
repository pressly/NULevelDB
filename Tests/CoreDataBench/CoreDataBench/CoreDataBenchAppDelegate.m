//
//  CoreDataBenchAppDelegate.m
//  CoreDataBench
//
//  Created by Brent Gulanowski on 11-08-05.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "CoreDataBenchAppDelegate.h"

#import "MasterViewController.h"
#import "NULDBTestCompany.h"
#import "NULDBTestUtilities.h"


@interface CoreDataBenchAppDelegate ()

- (NSURL *)storeURL;

@end


@implementation CoreDataBenchAppDelegate

@synthesize window = _window;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize navigationController = _navigationController;

+ (void)initialize {
    if([self class] == [CoreDataBenchAppDelegate class]) {
        srandom(TEST_RANDOM_SEED);
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.

    MasterViewController *controller = [[MasterViewController alloc] initWithNibName:@"MasterViewController" bundle:nil];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
    self.window.rootViewController = self.navigationController;
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
    
    NSError *error = nil;
    
    if(![[NSFileManager defaultManager] removeItemAtURL:[self storeURL] error:&error])
        NSLog(@"Couldn't delete core data store: %@", error);
    else {
        __managedObjectContext = nil;
        __persistentStoreCoordinator = nil;
    }
    
    NSMutableArray *names = [NSMutableArray array];
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    NSLog(@"Starting Core Data tests");
    
    for(int i=0; i<5; ++i) {
        
        NULDBTestCompany *company = [NULDBTestCompany companyOf100];
        
        [names addObject:[company name]];
    }
    
    
    NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];

    NSLog(@"Finished storing. Took %0.4f seconds. Starting loading.", end - start);
    
    
    [self.managedObjectContext reset];

    
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Company"];

    fetch.relationshipKeyPathsForPrefetching = [NSArray arrayWithObjects:@"addresses",
                                                @"workers.address",
                                                @"workers.phone",
                                                @"roles.manager.address",
                                                @"roles.manager.phone",
                                                nil];
    fetch.predicate = [NSPredicate predicateWithFormat:@"name in %@", names];
    
    start = end;
    

    NSArray *companies = [self.managedObjectContext executeFetchRequest:fetch error:&error];

    
    for(NULDBTestCompany *company in companies) {
        NSLog(@"Workers for company %@: %@", company.name, [[[company.workers valueForKey:@"fullName"] allObjects] componentsJoinedByString:@", "]);
        NSLog(@"Addresses for company %@: %@", company.name, [[[company.addresses valueForKey:@"description"] allObjects] componentsJoinedByString:@" "]);
    }
    
    end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Finished loading. Took %0.4f seconds. Starting deleting.", end - start);
    
    for(NULDBTestCompany *company in companies) {
        [self.managedObjectContext deleteObject:company];
        [self.managedObjectContext save:NULL];
    }
    
    end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"Finished deleting. Took %0.4f seconds. Done testing", end - start);
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
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"CoreDataBench" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [self storeURL];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
    {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)storeURL {
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"CoreDataBench.sqlite"];
}

@end
