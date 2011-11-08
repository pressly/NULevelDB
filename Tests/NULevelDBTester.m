//
//  NULevelDBTester.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NULevelDBTester.h"

#import "NULDBTestCompany.h"

#import <NULevelDB/NULDBDB.h>


@implementation NULevelDBTester

- (void)setDatabase:(id)aDB {
    NSParameterAssert([aDB isKindOfClass:[NULDBDB class]]);
    if(aDB != database)
        database = aDB;
}

- (id)database {
    return database;
}


@end

@implementation NULDBDB (NUTestDatabase)

- (void)saveObjects:(NSArray *)objects {
    for(id<NULDBSerializable>object in objects)
        [self storeObject:object];
}

- (NSDictionary *)loadObjects:(NSArray *)keysORIDs {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[keysORIDs count]];
    
    for(NSString *key in keysORIDs)
        [dict setObject:[self storedObjectForKey:key] forKey:key];
    
    return [dict copy];
}

- (void)deleteObjects:(NSArray *)keysOrIDs {
    for(NSString *key in keysOrIDs)
        [self deleteStoredObjectForKey:key];
}

@end
