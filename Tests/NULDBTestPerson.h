//
//  NULDBTestPerson.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NULDBDB.h"


@class NULDBTestAddress;
@class NULDBTestPhone;

@interface NULDBTestPerson : NSObject<NULDBSerializable>

@property (retain) NSString *uniqueID;
@property (retain) NSString *firstName;
@property (retain) NSString *lastName;
@property (retain) NULDBTestAddress *address;
@property (retain) NULDBTestPhone *phone;

+ (NULDBTestPerson *)randomPerson;

@end
