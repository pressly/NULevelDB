//
//  NULDBModel.h
//  CoreDataBench
//
//  Created by Brent Gulanowski on 11-08-05.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef NULDBTEST_CORE_DATA

@protocol NULDBSerializable <NSObject>

- (NSString *)storageKey;
- (NSArray *)propertyNames;

@optional
- (void)awakeFromStorage:(NSString *)storageKey;

@end

// Protocol suitable for serializing internal/leaf nodes
@protocol NULDBPlistTransformable <NSObject>

- (id)initWithPropertyList:(NSDictionary *)values;
- (NSDictionary *)plistRepresentation;

@end

#else

#import "NULDBDB.h"
#endif

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
