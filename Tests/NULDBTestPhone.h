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
- (id)initWithString:(NSString *)string;

@property NSInteger areaCode; // must be < 1000
@property NSInteger exchange; // must be < 1000
@property NSInteger line; // must be < 10000

+ (NULDBTestPhone *)randomPhone;
- (NSString *)string;

@end
