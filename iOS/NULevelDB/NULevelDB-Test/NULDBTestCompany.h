//
//  NULDBTestCompany.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NULDBDB.h"


@class NULDBTestPerson, NULDBTestAddress;

@interface NULDBTestCompany : NSObject<NULDBSerializable>

@property (retain) NSString *name;
@property (retain) NULDBTestPerson *supervisor;
@property (retain) NSArray *workers; // persons
@property (retain) NSDictionary *management; // persons keyed by title
@property (retain) NULDBTestAddress *mainAddress;
@property (retain) NSDictionary *secondaryAddresses; // addresses keyed by purpose

+ (NULDBTestCompany *)randomCompany;

@end
