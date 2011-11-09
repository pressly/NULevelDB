//
//  NULDBModel.h
//  CoreDataBench
//
//  Created by Brent Gulanowski on 11-08-05.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <NULevelDB/NULDBDB.h>


@interface NULDBTestModel :

#ifdef NULDBTEST_CORE_DATA
NSManagedObject

#else
NSObject<NULDBSerializable>

- (id)objectID;
- (void)willAccessValueForKey:(NSString *)key;
- (void)didAccessValueForKey:(NSString *)key;

#endif

@end
