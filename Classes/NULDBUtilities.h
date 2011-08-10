//
//  NULDBUtilities.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-10.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <leveldb/db.h>


using namespace leveldb;


#define NULDBLog(frmt, ...) do{ if(logging) NSLog((frmt), ##__VA_ARGS__); } while(0)


extern Class stringClass;
extern Class dataClass;
extern Class dictClass;


extern NSData *NULDBEncodedObject(id<NSCoding>object);
extern id NULDBDecodedObject(NSData *data);

static inline Slice NULDBSliceFromObject(id<NSCoding> object) {
    return Slice((const char *)[d bytes], (size_t)[d length]);
}

static inline id NULDBObjectFromSlice(Slice &slice) {
    return NULDBDecodedObject([NSData dataWithBytes:slice.data() length:slice.size()]);
}


@interface NULDBUtilities : NSObject

@end
