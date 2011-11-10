//
//  NULDBDB+Testing.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-02.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBDB+Testing.h"
#import "NULDBTestUtilities.h"


@implementation NULDBDB (NULDBDB_Testing)

- (NSTimeInterval)timedPutWithDictionary:(NSDictionary *)dict {
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    for(id key in [dict allKeys])
        [self storeValue:[dict objectForKey:key] forKey:key];
    
    return [NSDate timeIntervalSinceReferenceDate] - start;
}

- (NSTimeInterval)put:(NSUInteger)count valuesOfSize:(NSUInteger)size data:(NSDictionary **)data {
    
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:count];
    int width = (int)log10((double)count) + 1;
    
    for (NSUInteger i=0; i<count; ++i)
        [d setObject:newRandomString(size) forKey:[NSString stringWithFormat:@"%0*d", width, i]];
    
    NSLog(@"Starting put test with %u values of %u bytes", count, size);
    
    NSTimeInterval duration = [self timedPutWithDictionary:d];
    
    NSLog(@"Test took %.4f; %.6f per operation", duration, duration/count);
    
    if(NULL != data)
        *data = d;
    
    return duration;
}

- (NSTimeInterval)getValuesForTestKeys:(NSArray *)keys {
    
    NSLog(@"Starting get test with %u values", [keys count]);
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    NSUInteger misses = 0;
    
    for(id key in keys) {
        if(![self storedValueForKey:key])
            misses++;
    }
    
    
    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
    
    NSLog(@"Test took %.4f; %.6f per operation (%u misses)", duration, duration/[keys count], misses);
    
    return duration;
}

- (NSTimeInterval)deleteValuesForTestKeys:(NSArray *)keys {
    
    NSLog(@"Starting delete test with %u keys", [keys count]);
    
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    for(id key in keys)
        [self deleteStoredValueForKey:key];
    
    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
    
    NSLog(@"Test took %.4f; %.6f per operation", duration, duration/[keys count]);
    
    return duration;
}

@end
