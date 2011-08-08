//
//  NULDBTestPerson.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestPerson.h"

#import "NULDBTestPhone.h"
#import "NULDBTestAddress.h"
#import "NULDBTestUtilities.h"


@implementation NULDBTestPerson

#ifndef NULDBTEST_CORE_DATA
@synthesize firstName, lastName, address, company, phone;
#endif
@synthesize uniqueID;
@dynamic fullName;

static NSArray *properties;

+ (void)initialize {
    if([self class] == [NULDBTestPerson class]) {
        properties = [[NSArray alloc] initWithObjects:@"firstName", @"lastName", @"address", @"phone", nil];
    }
}

- (id)init {
    self = [super init];
    if(self) {
        self.uniqueID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
    }
    return self;
}


- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
}


#if STRICT_RELATIONAL
#pragma mark NULDBSerializable
- (NSArray *)propertyNames {
    return properties;
}

- (NSString *)storageKey {
    return self.uniqueID;
}

- (void)awakeFromStorage:(NSString *)storageKey {
    self.uniqueID = storageKey;
}
#endif


#pragma mark NULDBPlistTransformable
- (id)initWithPropertyList:(NSDictionary *)values {
    self = [super init];
    if(self) {
        self.firstName = [values objectForKey:@"f"];
        self.lastName = [values objectForKey:@"l"];
        self.address = [[NULDBTestAddress alloc] initWithPropertyList:[values objectForKey:@"a"]];
        self.phone = [[NULDBTestPhone alloc] initWithString:[values objectForKey:@"p"]];
    }
    return self;
}

- (NSDictionary *)plistRepresentation {

    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    
    if([self.firstName length]) [plist setObject:self.firstName forKey:@"f"];
    if([self.lastName length]) [plist setObject:self.lastName forKey:@"l"];
    if(self.address) [plist setObject:[self.address plistRepresentation] forKey:@"a"];
    if(self.phone) [plist setObject:[self.phone string] forKey:@"p"];
    
    return plist;
}


#pragma mark New
+ (NULDBTestPerson *)randomPerson {
   
#ifdef NULDBTEST_CORE_DATA
    NULDBTestPerson *result = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:CDBSharedContext()];
#else
    NULDBTestPerson *result = [[NULDBTestPerson alloc] init];
#endif
    
    result.firstName = NULDBRandomName();
    result.lastName = NULDBRandomName();
    result.address = [NULDBTestAddress randomAddress];
    result.phone = [NULDBTestPhone randomPhone];
    
#ifdef NULDBTEST_CORE_DATA
    [CDBSharedContext() save:NULL];
#endif
    
    return result;
}

@end
