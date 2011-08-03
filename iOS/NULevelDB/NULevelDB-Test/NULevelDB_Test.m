//
//  NULevelDB_Test.m
//  NULevelDB-Test
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULevelDB_Test.h"

#import "NULDBDB.h"
#import "NULDBDB+Testing.h"


@interface NULevelDB_Test ()

@property (retain) NULDBDB *db;

@end


@implementation NULevelDB_Test

@synthesize db;

- (void)setUp
{
    [super setUp];
    
    db = [[NULDBDB alloc] init];
}

- (void)tearDown
{
    [db destroy];
    [super tearDown];
}

- (void)testExample
{
    id testValue = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithFloat:3.0f*93-13.0f/4], @"number",
                    @"STRING", @"string",
                    [NSArray arrayWithObjects:@"1", @"2", @"3", nil], @"array",
                    nil];
    
    [db storeValue:testValue forKey:@"dictionary"];
    
    id retrieved = [db storedValueForKey:@"dictionary"];
    STAssertTrue([testValue isEqual:retrieved], @"Stored value not equal on retrieval: %@ vs %@", retrieved, testValue);
}

- (void)testPut10By1000 {
    [db put:10 valuesOfSize:1000 data:NULL];
}

- (void)testPut100By100 {
    [db put:100 valuesOfSize:100 data:NULL];
}

- (void)testPut1000By10 {
    [db put:1000 valuesOfSize:10 data:NULL];
}

@end
