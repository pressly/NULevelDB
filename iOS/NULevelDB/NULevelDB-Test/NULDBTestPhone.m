//
//  NULDBTestPhone.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestPhone.h"

@implementation NULDBTestPhone

@synthesize areaCode, exchange, line;

- (id)initWithAreaCode:(NSUInteger)a exchange:(NSUInteger)e line:(NSUInteger)l {
    self = [super init];
    if(self) {
        self.areaCode = a;
        self.exchange = e;
        self.line = l;
    }
    return self;
}

- (id)initWithNumber:(NSString *)number {

    NSScanner *scanner = [NSScanner scannerWithString:number];
    NSInteger a, e, l;
    
    [scanner scanString:@"(" intoString:NULL];
    [scanner scanInteger:&a];
    [scanner scanString:@") " intoString:NULL];
    [scanner scanInteger:&e];
    [scanner scanString:@"-" intoString:NULL];
    [scanner scanInteger:&l];

    return [self initWithAreaCode:a exchange:e line:l];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if(self) {
        self.areaCode = [aDecoder decodeIntegerForKey:@"a"];
        self.exchange = [aDecoder decodeIntegerForKey:@"e"];
        self.line = [aDecoder decodeIntegerForKey:@"l"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:areaCode forKey:@"a"];
    [aCoder encodeInteger:exchange forKey:@"e"];
    [aCoder encodeInteger:line forKey:@"l"];
}

@end
