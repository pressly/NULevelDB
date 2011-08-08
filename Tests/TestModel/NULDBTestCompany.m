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

@synthesize name, supervisor, workers, management, addresses, mainAddress, secondaryAddresses;

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
+ (NULDBTestCompany *)randomCompanyWithWorkers:(NSUInteger)wcount managers:(NSUInteger)mcount addresses:(NSUInteger)acount {
    
#if NULDBTEST_CORE_DATA
    NULDBTestCompany *result = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:CDBSharedContext()];
#else
    NULDBTestCompany *result = [[NULDBTestCompany alloc] initWithName:NULDBRandomName()];
#endif
    NSMutableSet *set = [NSMutableArray arrayWithCapacity:wcount];
    
    for (int i = 0; i < wcount; ++i)
        [set addObject:[NULDBTestPerson randomPerson]];
    
    result.supervisor = [NULDBTestPerson randomPerson];
    result.workers = set;
    
    NSMutableDictionary *management = [NSMutableDictionary dictionaryWithCapacity:mcount];
    NSMutableSet *selectedTitles = [NSMutableSet setWithCapacity:mcount];
    
    if(mcount >= [titles count]) {
        [selectedTitles addObjectsFromArray:titles];
        for (int i=[titles count]; i<mcount; ++i)
            [selectedTitles addObject:[NSString stringWithFormat:@"Boss %d", i]];
    }
    else {
        while([selectedTitles count] < mcount)
            [selectedTitles addObject:[titles objectAtIndex:Random_int_in_range(0, [titles count])]];
    }
    
    for(NSString *title in selectedTitles)
        [management setObject:[NULDBTestPerson randomPerson] forKey:title];
    
    result.management = management;
//#ifdef NULDBTEST_CORE_DATA
//    NULDBTestAddress *main = [NULDBTestAddress randomAddress];
//    
//    result.primaryAddressID = [[[main objectID] URIRepresentation] absoluteString];
//#else
//    result.mainAddress = [NULDBTestAddress randomAddress];
//    result.secondaryAddresses = [NSArray arrayWithObjects:[NULDBTestAddress randomAddress],
//                                 random()&1 ? [NULDBTestAddress randomAddress] : nil, nil];
//#endif
    NSMutableSet *adds = [NSMutableSet set];
    
    for (int i=0; i<acount; ++i)
        [adds addObject:[NULDBTestAddress randomAddress]];
    
    result.addresses = adds;
    
#if NULDBTEST_CORE_DATA
    [CDBSharedContext() save:NULL];
#endif
    
    return result;
}

+ (NULDBTestCompany *)randomSizedCompany {
    return [self randomCompanyWithWorkers:Random_int_in_range(2, 50)
                                 managers:Random_int_in_range(0, [titles count]/2+1)
                                addresses:(random()&1 + 1)];
}

+ (NULDBTestCompany *)companyOf100 {
    return [self randomCompanyWithWorkers:100 managers:10 addresses:5];
}

+ (NULDBTestCompany *)companyOf1000 {
    return [self randomCompanyWithWorkers:1000 managers:25 addresses:10];
}

@end
