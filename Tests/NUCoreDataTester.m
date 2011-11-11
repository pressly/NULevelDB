//
//  NUCoreDataTester.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NUCoreDataTester.h"

#import "NULDBTestCompany.h"

#import <CoreData/CoreData.h>


@implementation NUCoreDataTester

@synthesize database;

@end


@implementation NSManagedObjectContext (NUTestDatabase)

static NSFetchRequest *personsFetch;
static NSFetchRequest *addressesFetch;
static NSFetchRequest *phonesFetch;

+ (void)load {
    @autoreleasepool {
        personsFetch = [NSFetchRequest fetchRequestWithEntityName:@"Person"];
        personsFetch.relationshipKeyPathsForPrefetching = [NSArray arrayWithObjects:@"company", @"address", @"phone", @"role", nil];
        personsFetch.returnsObjectsAsFaults = NO;
        addressesFetch = [NSFetchRequest fetchRequestWithEntityName:@"Address"];
        addressesFetch.relationshipKeyPathsForPrefetching = [NSArray arrayWithObjects:@"company", @"person", nil];
        addressesFetch.returnsObjectsAsFaults = NO;
        phonesFetch = [NSFetchRequest fetchRequestWithEntityName:@"Phone"];
        phonesFetch.relationshipKeyPathsForPrefetching = [NSArray arrayWithObject:@"person"];
        phonesFetch.returnsObjectsAsFaults = NO;
    }
}

- (void)saveObjects:(NSArray *)objects {
    [self save:NULL];
//    [self reset];
}

- (NSDictionary *)loadObjects:(NSArray *)keysOrIDs {
    
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    for(NSString *idString in keysOrIDs) {
        
        NSManagedObjectID *objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:[NSURL URLWithString:idString]];
        NSManagedObject *object = [self objectWithID:objectID];
        
        if([[[objectID entity] name] isEqualToString:@"Company"]) {
            
            NSString *name = [(NULDBTestCompany *)object name];
            
            // load the workers
            personsFetch.predicate = [NSPredicate predicateWithFormat:@"self in %@", [(NULDBTestCompany *)object workers]];
            NSArray *workers = [self executeFetchRequest:personsFetch error:NULL];
            NSAssert([workers count] > 0, @"no workers for company %@", name);
            
            // load the addresses
            addressesFetch.predicate = [NSPredicate predicateWithFormat:@"self in %@ or self in %@", [(NULDBTestCompany *)object addresses], [workers valueForKey:@"address"]];
            NSArray *addresses = [self executeFetchRequest:addressesFetch error:NULL];
            NSAssert([addresses count] > 0, @"no addresses for company %@", name);
            
            // load the phones
            phonesFetch.predicate = [NSPredicate predicateWithFormat:@"self in %@", [workers valueForKey:@"phone"]];
            NSArray *phones = [self executeFetchRequest:phonesFetch error:NULL];
            NSAssert([phones count] > 0, @"no phones for workers of company %@", name);
        }
        
        if(nil != object)
            [results setObject:object forKey:idString];
    }
    
    return [results copy];
}

- (void)deleteObjects:(NSArray *)keysOrIDs {
    
    for(NSString *idString in keysOrIDs) {
        
        NSURL *uri = [NSURL URLWithString:idString];
        NSManagedObjectID *objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
        NSManagedObject *object = [self objectWithID:objectID];
        
        if(nil != object)
            [self deleteObject:object];
    }
    
    [self save:NULL];
}

@end