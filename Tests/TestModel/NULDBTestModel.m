//
//  NULDBModel.m
//  CoreDataBench
//
//  Created by Brent Gulanowski on 11-08-05.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestModel.h"

@implementation NULDBTestModel

#ifndef NULDBTEST_CORE_DATA
- (id)objectID { return nil; }
- (void)willAccessValueForKey:(NSString *)key {}
- (void)didAccessValueForKey:(NSString *)key {}
- (NSString *)storageKey { return nil; }
- (NSArray *)propertyNames { return nil; }
#endif

@end
