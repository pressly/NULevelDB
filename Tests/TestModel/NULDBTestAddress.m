//
//  NULDBTestAddress.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestAddress.h"

#import "NULDBTestUtilities.h"


@implementation NULDBTestAddress

#ifndef NULDBTEST_CORE_DATA
@synthesize street, city, state, postalCode;
#endif
@synthesize uniqueID;

#if STRICT_RELATIONAL
static NSArray *propertyNames;
#endif
static NSArray *roads;

#pragma mark NSObject
+ (void)initialize {
    if([self class] == [NULDBTestAddress class]) {
#if STRICT_RELATIONAL
        propertyNames = [[NSArray alloc] initWithObjects:@"street", @"city", @"state", @"postalCode", nil];
#endif
        roads = [[NSArray alloc] initWithObjects:@"St.", @"Rd.", @"Ave", @"Cres.", @"Blvd.", @"Ct.", @"Ln.", nil];
    }
}

- (id)init {
    self = [super init];
    if(self)
        self.uniqueID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, %@, %@, %@.", self.street, self.city, self.state, self.postalCode];
}

#ifndef NULDBTEST_CORE_DATA
- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass:[NULDBTestAddress class]])
        return NO;
    
    NULDBTestAddress *address = (NULDBTestAddress *)object;
    
    return ([self.street isEqualToString:address.street]
            && [self.city isEqualToString:address.city]
            && [self.state isEqualToString:address.state]
            && [self.postalCode isEqualToString:address.postalCode]);
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@%@%@%@", self.street, self.city, self.state, self.postalCode] hash];
}
#endif


#if STRICT_RELATIONAL
#pragma mark NULDBSerializable
- (NSString *)storageKey {
    return self.uniqueID;
}

- (NSArray *)propertyNames {
    return propertyNames;
}

- (void)awakeFromStorage:(NSString *)storageKey {
    self.uniqueID = storageKey;
}


#else
#pragma mark NULDBPlistTransformable
- (id)initWithPropertyList:(NSDictionary *)values {
    self = [self init];
    if(self) {
        self.street = [values objectForKey:@"street"];
        self.city = [values objectForKey:@"city"];
        self.state = [values objectForKey:@"state"];
        self.postalCode = [values objectForKey:@"postalCode"];
    }
    return self;
}

- (NSDictionary *)plistRepresentation {

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if(self.street)[dict setObject:self.street forKey:@"street"];
    if(self.city)[dict setObject:self.city forKey:@"city"];
    if(self.state)[dict setObject:self.state forKey:@"state"];
    if(self.postalCode)[dict setObject:self.postalCode forKey:@"postalCode"];
    
    return dict;
}
#endif


#pragma mark New
static inline NSString *randomPostalCode () {

    char buffer[8];
    
    buffer[0] = Random_alpha_char()-0x20;
    buffer[1] = Random_digit_char();
    buffer[2] = Random_alpha_char()-0x20;
    buffer[3] = ' ';
    buffer[4] = Random_digit_char();
    buffer[5] = Random_alpha_char()-0x20;
    buffer[6] = Random_digit_char();
    buffer[7] = '\0';
    
    return [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
}

+ (NULDBTestAddress *)randomAddress {
    
#if NULDBTEST_CORE_DATA
    NSManagedObjectContext *moc = CDBSharedContext();
    NULDBTestAddress *result =  [NSEntityDescription insertNewObjectForEntityForName:@"Address" inManagedObjectContext:moc];
#else
    NULDBTestAddress *result = [[NULDBTestAddress alloc] init];
#endif
    
    result.street = [NSString stringWithFormat:@"%d %@ %@",
                     Random_int_in_range(1, 9999), NULDBRandomName(), [roads objectAtIndex:Random_int_in_range(0, [roads count]-1)]];
    result.city = NULDBRandomName();
    result.state = NULDBRandomName();
    result.postalCode = randomPostalCode();
    
#if NULDBTEST_CORE_DATA
    [CDBSharedContext() save:NULL];
#endif
    
    return result;
}

@end
