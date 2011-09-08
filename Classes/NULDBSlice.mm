//
//  NULDBSlice.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBSlice.h"

#include <leveldb/slice.h>


using namespace leveldb;

@implementation NULDBSlice {
    Slice *slice;
}


@dynamic data, string, propertyList, object;

#pragma mark Accessors
- (NSData *)data {
    return [NSData dataWithBytes:slice->data() length:slice->size()];
}

- (NSString *)string {
    return [[[NSString alloc] initWithBytes:slice->data() length:slice->size() encoding:NSUTF8StringEncoding] autorelease];
}

- (id)propertyList {
    
    NSError *error = nil;    
    id plist = [NSPropertyListSerialization propertyListWithData:[self data]
                                                         options:NSPropertyListImmutable
                                                          format:NULL
                                                           error:&error];
    
    if(!plist)
        NSLog(@"Error decoding plist %@", error);
    
    return plist;
}

- (id<NSCoding>)object {
    return [NSKeyedUnarchiver unarchiveObjectWithData:[self data]];
}

- (void)finalize {
    delete slice;
}

- (id)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        slice = new Slice((const char *)[data bytes], [data length]);
    }
    
    return self;
}

- (id)initWithString:(NSString *)string {
    self = [super init];
    if(self) {
        slice = new Slice([string UTF8String], [string length]);
    }
    return self;
}

- (id)initWithPropertyList:(id)plist {
    
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&error];
    if(nil == error) {
        NSLog(@"Could not instantiate data for property list %@; error: %@", plist, error);
        return nil;
    }
    
    return [self initWithData:data];
}

- (id)initWithObject:(id<NSCoding>)object {
    return [self initWithData:[NSKeyedArchiver archivedDataWithRootObject:object]];
}


+ (id)sliceWithData:(NSData *)data {
    return [[[self alloc] initWithData:data] autorelease];
}

+ (id)sliceWithString:(NSString *)string {
    return [[[self alloc] initWithString:string] autorelease];
}

+ (id)sliceWithPropertyList:(id)plist {
    return [[[self alloc] initWithPropertyList:plist] autorelease];
}

+ (id)initWithObject:(id<NSCoding>)object {
    return [[[self alloc] initWithObject:object] autorelease];
}

@end
