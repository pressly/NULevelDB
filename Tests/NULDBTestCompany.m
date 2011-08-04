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
static NSArray *titles;

+ (void)initialize {
    if([self class] == [NULDBTestCompany class]) {
        propertyNames = [[NSArray alloc] initWithObjects:@"supervisor", @"workers", @"management", @"mainAddress", @"secondaryAddresses", nil];
        titles = [[NSArray alloc] initWithObjects:@"CEO", @"VP Operations", @"VP Sales", @"VP Logistics", @"Shop Manager", @"Human Resources", @"Accountant", @"COO", @"Chief Scientist", @"Mad Scientist", @"Boy Wonder", @"Crypt Keeper", @"Slave Driver", @"Middle Manager", @"Enforcer", @"Lion Tamer", @"Captain", @"Major", @"Colonel", @"General", nil];
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
    
    NULDBTestCompany *result = [[NULDBTestCompany alloc] initWithName:NULDBRandomName()];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:20];
    int count = Random_int_in_range(2, 20);
    
    for (int i = 0; i < count; ++i)
        [array addObject:[NULDBTestPerson randomPerson]];
    
    result.supervisor = [NULDBTestPerson randomPerson];
    result.workers = array;
    
    count = Random_int_in_range(0, [titles count]/2+1);
    
    NSMutableDictionary *management = [NSMutableDictionary dictionaryWithCapacity:count];
    
    for(int i=0; i<count; ++i)
        [management setObject:[NULDBTestPerson randomPerson] forKey:[titles objectAtIndex:Random_int_in_range(0, [titles count])]];
    
    result.management = management;
    result.mainAddress = [NULDBTestAddress randomAddress];
    result.secondaryAddresses = [NSArray arrayWithObjects:[NULDBTestAddress randomAddress],
                                 random()&1 ? [NULDBTestAddress randomAddress] : nil, nil];
    
    return result;
}

@end
