//
//  NULDBDB+Testing.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <NULevelDB/NULDBDB.h>


@interface NULDBDB (NULDBDB_Testing)

- (NSTimeInterval)put:(NSUInteger)count valuesOfSize:(NSUInteger)size data:(NSDictionary **)data;
- (NSTimeInterval)getValuesForTestKeys:(NSArray *)keys;
- (NSTimeInterval)deleteValuesForTestKeys:(NSArray *)keys;

@end
