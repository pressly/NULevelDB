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

@interface NULDBTestPerson : _NULDBTestPerson<
#if STRICT_RELATIONAL
NULDBSerializable
#else
NULDBPlistTransformable
#endif
>

@property (retain) NSString *uniqueID;

@property (readonly) NSString *fullName;

- (NSDictionary *)plistRepresentation;
+ (NULDBTestPerson *)randomPerson;

@end
