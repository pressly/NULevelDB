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

#import "NULDBTestPhone.h"
#import "NULDBTestPerson.h"
#import "NULDBTestAddress.h"


@interface NULDBWrapper : NSObject<NULDBSerializable>
@property (retain) NSString *identifier;
@property (retain) id object;
@end

@implementation NULDBWrapper

@synthesize identifier, object;

- (NSArray *)propertyNames {
    return [NSArray arrayWithObject:@"object"];
}

- (NSString *)storageKey {
    return identifier;
}

- (id)initWithObject:(id)obj identifier:(NSString *)ident {
    self.object = obj;
    self.identifier = ident;
    return self;
}

@end


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
    id e = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithFloat:3.0f*93-13.0f/4], @"number",
                    @"STRING", @"string",
                    [NSArray arrayWithObjects:@"1", @"2", @"3", nil], @"array",
                    nil];
    
    [db storeValue:e forKey:@"dictionary"];
    
    id a = [db storedValueForKey:@"dictionary"];
    STAssertTrue([e isEqual:a], @"Stored value not equal on retrieval. Expected %@; actual: %@", e, a);
}

// These performance tests aren't very interesting in relation to iOS
//- (void)testPut10By1000 {
//    [db put:10 valuesOfSize:1000 data:NULL];
//}
//
//- (void)testPut100By100 {
//    [db put:100 valuesOfSize:100 data:NULL];
//}
//
//- (void)testPut1000By10 {
//    [db put:1000 valuesOfSize:10 data:NULL];
//}

- (void)testKeyedArchiveSerialization {
    
    NULDBTestPhone *e = [[NULDBTestPhone alloc] initWithAreaCode:416 exchange:967 line:1111];
    NSString *key = @"phone_1";
    
    [db storeValue:e forKey:key];
    
    id a = [db storedObjectForKey:key];
    
    STAssertTrue([e isEqual:a], @"Stored value discrepancy. Expected: %@; actual: %@.", e, a);
}

- (NULDBTestAddress *)makeTestAddress {
    
    NULDBTestAddress *address = [[NULDBTestAddress alloc] init];
    
    address.street = @"100 Avenue Road";
    address.city = @"Toronto";
    address.state = @"Ontario";
    address.postalCode = @"M4T 9G3";
    
    return address;
}

- (void)testPlistSerialization {
    
    NULDBTestAddress *address = [self makeTestAddress];
    NULDBWrapper *e = [[NULDBWrapper alloc] initWithObject:address identifier:address.uniqueID];
    
    [db storeObject:e];
    
    
    id wrapper = [db storedObjectForKey:address.uniqueID];
    
    STAssertTrue([wrapper isKindOfClass:[NULDBWrapper class]], @"Wrapper class fail; got %@", wrapper);
    
    id a = [wrapper object];
    
    STAssertTrue([a isKindOfClass:[NULDBTestAddress class]], @"Wrapped object fail; got %@", a);
    
    [a setUniqueID:address.uniqueID];
    
    STAssertTrue([address isEqual:a], @"Stored value discrepancy. Expected: %@; actual: %@.", e, a);
}

- (void)testGraphSerialization {
    
    
}

@end
