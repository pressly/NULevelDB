//
//  NULDBTestPerson.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "_NULDBTestPerson.h"


@class NULDBTestAddress;
@class NULDBTestPhone;

@interface NULDBTestPerson : _NULDBTestPerson<NULDBSerializable, NULDBPlistTransformable>

@property (retain) NSString *uniqueID;

+ (NULDBTestPerson *)randomPerson;

@end
