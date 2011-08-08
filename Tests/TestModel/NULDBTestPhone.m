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

#ifndef NULDBTEST_CORE_DATA
@synthesize areaCode, exchange, line;
#endif

#pragma mark NSObject
#ifndef NULDBTEST_CORE_DATA
- (BOOL)isEqual:(id)other {
    if(![super isEqual:other])
        return [self hash] == [other hash];
    return YES;
}

- (NSUInteger)hash {
    return self.lineValue + self.exchangeValue * 10000 + self.areaCodeValue * 10000000;
}
#endif

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%@) %@-%@", [super description], self.areaCode, self.exchange, self.line];
}

#pragma mark Initializers

#if STRICT_RELATIONAL
static NSArray *propertyNames;
+ (void)initialize {
    if([self class] == [NULDBTestPhone class]) {
        propertyNames = [[NSArray alloc] initWithObjects:@"areaCode", @"exchange", @"line", nil];
    }
}
#endif

- (id)initWithAreaCode:(NSUInteger)a exchange:(NSUInteger)e line:(NSUInteger)l {
    self = [super init];
    if(self) {
        self.areaCode = [NSNumber numberWithUnsignedInteger:a];
        self.exchange = [NSNumber numberWithUnsignedInteger:e];
        self.line = [NSNumber numberWithUnsignedInteger:l];
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


#pragma mark NSCoding
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
    [aCoder encodeObject:self.areaCode forKey:@"a"];
    [aCoder encodeObject:self.exchange forKey:@"e"];
    [aCoder encodeObject:self.line forKey:@"l"];
}


#pragma mark NULDBSerializable
#if STRICT_RELATIONAL
- (NSString *)storageKey {
    return [self string];
}

- (NSArray *)propertyNames {
    return propertyNames;
}
#endif


#pragma mark New
+ (NULDBTestPhone *)randomPhone {
    
    int a = Random_int_in_range(100, 999);
    int x = Random_int_in_range(0, 999);
    int l = Random_int_in_range(0, 9999);
    
#if NULDBTEST_CORE_DATA
    NULDBTestPhone *phone = [NSEntityDescription insertNewObjectForEntityForName:@"Phone" inManagedObjectContext:CDBSharedContext()];
    phone.areaCodeValue = a;
    phone.exchangeValue = x;
    phone.lineValue = l;
    [CDBSharedContext() save:NULL];
    return phone;
#else
    return [[NULDBTestPhone alloc] initWithAreaCode:a exchange:x line:l];
#endif
}

- (NSString *)string {
    return [NSString stringWithFormat:@"(%d) %03d-%04d", [self.areaCode intValue], [self.exchange intValue], [self.line intValue]];
}

@end
