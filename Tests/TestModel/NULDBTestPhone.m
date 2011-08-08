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
    return self.lineValue + self.exchangeValue * 10000 + self.areaCodeValue * 10000000;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%d) %d-%d", [super description], areaCode, exchange, line];
}

#pragma mark Initializers

- (id)initWithAreaCode:(NSUInteger)a exchange:(NSUInteger)e line:(NSUInteger)l {
    self = [super init];
    if(self) {
        self.areaCodeValue = a;
        self.exchangeValue = e;
        self.lineValue = l;
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
        self.areaCode = [aDecoder decodeObjectForKey:@"a"];
        self.exchange = [aDecoder decodeObjectForKey:@"e"];
        self.line = [aDecoder decodeObjectForKey:@"l"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:areaCode forKey:@"a"];
    [aCoder encodeObject:exchange forKey:@"e"];
    [aCoder encodeObject:line forKey:@"l"];
}


#pragma mark New
+ (NULDBTestPhone *)randomPhone {
#if NULDBTEST_CORE_DATA
    NULDBTestPhone *phone = [NSEntityDescription insertNewObjectForEntityForName:@"Phone" inManagedObjectContext:CDBSharedContext()];
    phone.areaCodeValue = Random_int_in_range(0, 999);
    phone.exchangeValue = Random_int_in_range(0, 999);
    phone.lineValue = Random_int_in_range(0, 9999);
    [CDBSharedContext() save:NULL];
    return phone;
#else
    return [[NULDBTestPhone alloc] initWithAreaCode:Random_int_in_range(0, 999) exchange:Random_int_in_range(0, 999) line:Random_int_in_range(0, 9999)];
#endif
}

- (NSString *)string {
    return [NSString stringWithFormat:@"(%d) %d-%d", areaCode, exchange, line];
}

@end
