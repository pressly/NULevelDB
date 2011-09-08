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
#import "NULDBTestRole.h"
#import "NULDBTestUtilities.h"

@interface NULDBTestCompany ()
- (void)populateManagement;
@end


@implementation NULDBTestCompany

#ifndef NULDBTEST_CORE_DATA
@synthesize name, /*supervisor,*/ workers, addresses, primaryAddressID;
@dynamic mainAddress, secondaryAddresses;
#endif

@synthesize management;


static NSArray *propertyNames;
static NSArray *titles;

+ (void)initialize {
    if([self class] == [NULDBTestCompany class]) {
        propertyNames = [[NSArray alloc] initWithObjects:/*@"supervisor",*/ @"name", @"workers", @"management", @"mainAddress", @"addresses", nil];
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


#ifndef NULDBTEST_CORE_DATA
- (NSArray *)mainAddress {
    return [[self.addresses filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"uniqueID = %@", self.primaryAddressID]] allObjects];
}

- (NSArray *)secondaryAddresses {
    
    NSMutableSet *set = [self.addresses mutableCopy];
    NULDBTestAddress *main = [self.mainAddress lastObject];
    
    if(main)
        [set removeObject:main];
    
    return [set allObjects];
}

#endif

#pragma mark NULDBSerializable
- (NSString *)storageKey {
    return self.name;
}

- (NSArray *)propertyNames {
    return propertyNames;
}


#pragma mark NULDBPlistTransformable
- (id)initWithPropertyList:(NSDictionary *)values {
    self = [self init];
    if(self) {
        
    }
    return self;
}

- (NSDictionary *)plistRepresentation {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:self.name forKey:@"name"];
    [dict setObject:self.primaryAddressID forKey:@"primaryAddressID"];
    [dict setObject:[self.addresses valueForKey:@"plistRepresentation"] forKey:@"addresses"];
    
    if(!self.management)
        [self populateManagement];
    if([self.management count]) {
        
        NSMutableDictionary *mgmtPlist = [NSMutableDictionary dictionary];
        
        for(id key in [self.management allKeys])
            [mgmtPlist setObject:[[self.management objectForKey:key] plistRepresentation] forKey:key];
        
        [dict setObject:mgmtPlist forKey:@"management"];
    }
    
    if([self.workers count])
        [dict setObject:[self.workers valueForKey:@"plistRepresentation"] forKey:@"workers"];
    
    return dict;
}


#pragma mark New
- (void)populateManagement {
    
    NSUInteger count = [self.roles count];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
    
    for(NULDBTestRole *role in self.roles)
        [dict setObject:role.manager forKey:role.name];
    
    self.management = [dict copy];
}

+ (NULDBTestCompany *)randomCompanyWithWorkers:(NSUInteger)wcount managers:(NSUInteger)mcount addresses:(NSUInteger)acount {
    
    NSString *name = NULDBRandomName();
    
#if NULDBTEST_CORE_DATA
    NULDBTestCompany *result = [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:CDBSharedContext()];
    result.name = name;
#else
    NULDBTestCompany *result = [[NULDBTestCompany alloc] initWithName:name];
#endif
    NSMutableSet *set = [NSMutableSet setWithCapacity:wcount];
    
    for (int i = 0; i < wcount; ++i)
        [set addObject:[NULDBTestPerson randomPerson]];
    
//    result.supervisor = [NULDBTestPerson randomPerson];
    result.workers = set;

    
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
    

    NSMutableDictionary *management = [NSMutableDictionary dictionaryWithCapacity:mcount];
    
    for(NSString *title in selectedTitles)
        [management setObject:[NULDBTestPerson randomPerson] forKey:title];
    
#if NULDBTEST_CORE_DATA
    for(NSString *title in [management allKeys])
        [NULDBTestRole roleWithName:title company:result manager:[management objectForKey:title]];
#else
    result.management = management;
#endif

    NSMutableSet *adds = [NSMutableSet set];
    NULDBTestAddress *address = [NULDBTestAddress randomAddress];
    
    [adds addObject:address];
    
    for (int i=0; i<acount; ++i)
        [adds addObject:[NULDBTestAddress randomAddress]];
    
    result.addresses = adds;

#ifdef NULDBTEST_CORE_DATA
    [CDBSharedContext() save:NULL];
    result.primaryAddressID = [[[address objectID] URIRepresentation] absoluteString];
#else
    result.primaryAddressID = [address uniqueID];
#endif

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

+ (NULDBTestCompany *)companyOf10 {
    return [self randomCompanyWithWorkers:10 managers:2 addresses:1];
}

+ (NULDBTestCompany *)companyOf100 {
    return [self randomCompanyWithWorkers:100 managers:10 addresses:5];
}

+ (NULDBTestCompany *)companyOf1000 {
    return [self randomCompanyWithWorkers:1000 managers:25 addresses:10];
}

@end
