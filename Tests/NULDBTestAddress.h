//
//  NULDBTestAddress.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NULDBDB.h"


@interface NULDBTestAddress : NSObject<NULDBPlistTransformable>

@property (retain) NSString *uniqueID;

@property (retain) NSString *street;
@property (retain) NSString *city;
@property (retain) NSString *state;
@property (retain) NSString *postalCode;

+ (NULDBTestAddress *)randomAddress;

@end
