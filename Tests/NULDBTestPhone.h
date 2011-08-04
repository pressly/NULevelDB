//
//  NULDBTestPhone.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NULDBTestPhone : NSObject<NSCoding>

- (id)initWithAreaCode:(NSUInteger)a exchange:(NSUInteger)e line:(NSUInteger)l;
- (id)initWithNumber:(NSString *)number;

@property NSInteger areaCode; // must be < 1000
@property NSInteger exchange; // must be < 1000
@property NSInteger line; // must be < 10000

@end
