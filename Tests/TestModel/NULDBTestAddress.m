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

@synthesize uniqueID, street, city, state, postalCode;

static NSArray *roads = nil;

#pragma mark NSObject
+ (void)initialize {
    if([self class] == [NULDBTestAddress class]) {
        roads = [[NSArray alloc] initWithObjects:@"St.", @"Rd.", @"Ave", @"Cres.", @"Blvd.", @"Ct.", @"Ln.", nil];
    }
}

- (id)init {
    self = [super init];
    if(self)
        self.uniqueID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));

    return self;
}

- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass:[NULDBTestAddress class]])
        return NO;
    
    NULDBTestAddress *address = (NULDBTestAddress *)object;
    
    return ([street isEqualToString:address.street]
            && [city isEqualToString:address.city]
            && [state isEqualToString:address.state]
            && [postalCode isEqualToString:address.postalCode]);
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@%@%@%@", street, city, state, postalCode] hash];
}


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
    
    if(street)[dict setObject:street forKey:@"street"];
    if(city)[dict setObject:city forKey:@"city"];
    if(state)[dict setObject:state forKey:@"state"];
    if(postalCode)[dict setObject:postalCode forKey:@"postalCode"];
    
    return dict;
}


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
    NULDBTestAddress *result = [NSEntityDescription insertNewObjectForEntityForName:@"Address" inManagedObjectContext:CDBSharedContext()];
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
