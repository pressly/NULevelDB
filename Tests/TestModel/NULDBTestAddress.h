//
//  NULDBTestAddress.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "_NULDBTestAddress.h"


@interface NULDBTestAddress : _NULDBTestAddress<
#if STRICT_RELATIONAL
NULDBSerializable
#else
NULDBPlistTransformable
#endif
>

@property (retain) NSString *uniqueID;

+ (NULDBTestAddress *)randomAddress;

@end
