//
//  NULDBSlice.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NULDBSlice : NSObject

// Ensure you know which type you encoded
@property (readonly) NSData *data;
@property (readonly) NSString *string;
@property (readonly) id propertyList;
@property (readonly) id<NSCoding> object;

- (id)initWithData:(NSData *)data;
- (id)initWithString:(NSString *)string;
- (id)initWithPropertyList:(id)plist;
- (id)initWithObject:(id<NSCoding>)object;

+ (id)sliceWithData:(NSData *)data;
+ (id)sliceWithString:(NSString *)string;
+ (id)sliceWithPropertyList:(id)plist;
+ (id)initWithObject:(id<NSCoding>)object;

@end
