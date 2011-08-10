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


static inline Slice NULDBSliceFromObject(id<NSCoding> object) {
    
    char type = 'o';
    
    if([(id)object isKindOfClass:stringClass])    type = 's';
    else if([(id)object isKindOfClass:dataClass]) type = 'd';
    else if([(id)object isKindOfClass:dictClass]) type = 'h';
    
    NSMutableData *d = [NSMutableData dataWithBytes:&type length:1];
    
    switch (type) {
        case 's':
            [d appendData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding]];
            break;
            
        case 'd':
            [d appendData:(NSData *)object];
            break;
            
        case 'h':
            [d appendData:[NSPropertyListSerialization dataWithPropertyList:(id)object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL]];
            break;
            
        default:
            [d appendData:[NSKeyedArchiver archivedDataWithRootObject:object]];
            break;
    }
    
    return Slice((const char *)[d bytes], (size_t)[d length]);
}

static inline id<NSCoding> NULDBObjectFromSlice(Slice &slice) {
    
    NSData *d = [NSData dataWithBytes:slice.data() length:slice.size()];
    NSData *value = [d subdataWithRange:NSMakeRange(1, [d length] - 1)];
    
    char type;
    
    [d getBytes:&type length:1];
    
    switch (type) {
        case 's':
            return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
            break;
            
        case 'd':
            return value;
            break;
            
        case 'h':
            return [NSPropertyListSerialization propertyListWithData:value options:NSPropertyListImmutable format:NULL error:NULL];
            break;
            
        default:
            break;
    }
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}
@interface NULDBUtilities : NSObject

@end
