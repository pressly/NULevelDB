//
//  NULDBTestPhone.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "_NULDBTestPhone.h"


@interface NULDBTestPhone : _NULDBTestPhone<NSCoding>

- (id)initWithAreaCode:(NSUInteger)a exchange:(NSUInteger)e line:(NSUInteger)l;
- (id)initWithString:(NSString *)string;

+ (NULDBTestPhone *)randomPhone;
- (NSString *)string;

@end
