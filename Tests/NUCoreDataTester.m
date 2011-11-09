//
//  NUCoreDataTester.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NUCoreDataTester.h"

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
}

- (NSDictionary *)loadObjects:(NSArray *)keysOrRIDs {

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    for(NSString *idString in keysOrRIDs) {
        
        NSURL *uri = [NSURL URLWithString:idString];
        NSManagedObjectID *objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
        NSManagedObject *object = [self objectWithID:objectID];
        
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