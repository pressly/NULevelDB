//
//  NULDBTestCompany.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "_NULDBTestCompany.h"


@class NULDBTestPerson, NULDBTestAddress;

@interface NULDBTestCompany : _NULDBTestCompany<NULDBSerializable>

//@property (retain) NULDBTestPerson *supervisor;
@property (retain) NSDictionary *management; // persons keyed by title

- (NSDictionary *)plistRepresentation;

+ (NULDBTestCompany *)randomCompanyWithWorkers:(NSUInteger)wcount managers:(NSUInteger)mcount addresses:(NSUInteger)account;
+ (NULDBTestCompany *)randomSizedCompany;
+ (NULDBTestCompany *)companyOf10;
+ (NULDBTestCompany *)companyOf100;
+ (NULDBTestCompany *)companyOf1000;

@end
