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

#pragma mark NSObject
- (id)init {
    self = [super init];
    if(self)
        self.uniqueID = NSMakeCollectable(CFUUIDCreateString(NULL, CFUUIDCreate(NULL)));

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

@end
