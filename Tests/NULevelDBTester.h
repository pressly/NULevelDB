//
//  NULevelDBTester.h
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NUDatabaseTester.h"


typedef void(^NUDatabaseOperationBlock)(NULDBDB *database, NSDictionary *data, NSString *key);


@interface NULevelDBTester : NUDatabaseTester {
    NULDBDB *database;
}

- (void)runValuesTest:(NSUInteger)count size:(NSUInteger)size;
- (void)runDataTest:(NSUInteger)count size:(NSUInteger)size;
- (void)runStringTest:(NSUInteger)count size:(NSUInteger)size;

@end
