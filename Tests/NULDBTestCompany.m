//
//  NULDBTestCompany.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestCompany.h"

#import "NULDBTestPhone.h"
#import "NULDBTestPerson.h"
#import "NULDBTestAddress.h"
#import "NULDBTestUtilities.h"


@implementation NULDBTestCompany

@synthesize name, supervisor, workers, management, mainAddress, secondaryAddresses;

static NSArray *propertyNames;

+ (void)initialize {
    if([self class] == [NULDBTestCompany class]) {
        propertyNames = [[NSArray alloc] initWithObjects:@"supervisor", @"workers", @"management", @"mainAddress", @"secondaryAddresses", nil];
    }
}

- (id)initWithName:(NSString *)aName
{
    self = [super init];
    if (self) {
        self.name = aName;
    }
    
    return self;
}

#pragma mark NULDBSerializable
- (NSString *)storageKey {
    return name;
}

- (NSArray *)propertyNames {
    return propertyNames;
}


#pragma mark New
+ (NULDBTestCompany *)randomCompany {
    return [[NULDBTestCompany alloc] initWithName:NULDBRandomName()];
}

@end
