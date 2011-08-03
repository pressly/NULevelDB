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

@synthesize uniqueID, firstName, lastName, address, phone;

static NSArray *properties;

+ (void)initialize {
    if([self class] == [NULDBTestPerson class]) {
        properties = [[NSArray alloc] initWithObjects:@"firstName", @"lastName", @"address", @"phone", nil];
    }
}

- (id)init {
    self = [super init];
    if(self) {
        self.uniqueID = NSMakeCollectable(CFUUIDCreateString(NULL, CFUUIDCreate(NULL)));
    }
    return self;
}


#pragma mark NULDBSerializable
- (NSArray *)propertyNames {
    return properties;
}

- (NSString *)storageKey {
    return uniqueID;
}

- (void)awakeFromStorage:(NSString *)storageKey {
    self.uniqueID = storageKey;
}

@end
