//
//  NUCoreDataTester.h
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-11-08.
//  Copyright (c) 2011 NuLayer Inc. All rights reserved.
//

#import "NUDatabaseTester.h"

@interface NUCoreDataTester : NUDatabaseTester {
    NSManagedObjectContext *database;
}

@end
