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

@property NSInteger areaCode;
@property NSInteger exchange;
@property NSInteger line;

@end
