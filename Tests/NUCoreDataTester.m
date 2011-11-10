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

- (void)setDatabase:(id)aDB {
    NSParameterAssert([aDB isKindOfClass:[NSManagedObjectContext class]]);
    if(aDB != database)
        database = aDB;
}

- (id)database {
    return database;
}

@end


@implementation NSManagedObjectContext (NUTestDatabase)

- (void)saveObjects:(NSArray *)objects {
    [self save:NULL];
    [self reset];
}

- (NSDictionary *)loadObjects:(NSArray *)keysOrRIDs {
    
    static NSFetchRequest *fetch = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fetch = [NSFetchRequest fetchRequestWithEntityName:@"Company"];
        fetch.relationshipKeyPathsForPrefetching = [NSArray arrayWithObjects:@"addresses",
                                                    @"workers.address",
                                                    @"workers.phone",
                                                    @"roles.manager.address",
                                                    @"roles.manager.phone",
                                                    nil];
    });

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    for(NSString *idString in keysOrRIDs) {
        
        NSURL *uri = [NSURL URLWithString:idString];
        NSManagedObjectID *objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
        NSEntityDescription *entity = [objectID entity];
        NSManagedObject *object = [self objectWithID:objectID];
        
        if([[entity name] isEqualToString:@"Company"]) {
            fetch.predicate = [NSPredicate predicateWithFormat:@"name = %@", [(NULDBTestCompany *)object name]];
            object = [[self executeFetchRequest:fetch error:NULL] lastObject];
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