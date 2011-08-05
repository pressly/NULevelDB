//
//  NULDBTestPhone.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestPhone.h"
#import "NULDBTestUtilities.h"


@implementation NULDBTestPhone

@synthesize areaCode, exchange, line;

#pragma mark NSObject
- (BOOL)isEqual:(id)other {
    if(![super isEqual:other])
        return [self hash] == [other hash];
    return YES;
}

- (NSUInteger)hash {
    return line + exchange * 10000 + areaCode * 10000000;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%d) %d-%d", [super description], areaCode, exchange, line];
}

#pragma mark Initializers

- (id)initWithAreaCode:(NSUInteger)a exchange:(NSUInteger)e line:(NSUInteger)l {
    self = [super init];
    if(self) {
        self.areaCode = a;
        self.exchange = e;
        self.line = l;
    }
    return self;
}

- (id)initWithString:(NSString *)string {

    NSScanner *scanner = [NSScanner scannerWithString:string];
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


#pragma mark New
+ (NULDBTestPhone *)randomPhone {
    return [[NULDBTestPhone alloc] initWithAreaCode:Random_int_in_range(0, 999) exchange:Random_int_in_range(0, 999) line:Random_int_in_range(0, 9999)];
}

- (NSString *)string {
    return [NSString stringWithFormat:@"(%d) %d-%d", areaCode, exchange, line];
}

@end
