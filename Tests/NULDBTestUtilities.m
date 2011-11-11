//
//  NULDBTestUtilities.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestUtilities.h"

#import "NULDBTestPerson.h"


NSString *NULDBRandomName( void ) {
    
    static char cons[21] = "bcdfghjklmnpqrstvwxyz";
    static char vows[6] = "aeiouy";
    static char buffer[256];
#if 1
    int fragments = Random_int_in_range(1, 4);
    int l=0;
    
    if(Random_int_in_range(0,10) > 2)
        buffer[l++] = cons[Random_int_in_range(0,19)];
    
    for(int i=0; i<fragments; ++i) {
        
        int a = Random_int_in_range(0,1), b = Random_int_in_range(1,3), c = Random_int_in_range(1,2);
        
        for(int j=0; j<a; ++j)
            buffer[l++] = cons[Random_int_in_range(0,19)];
        
        for(int j=0; j<b; ++j)
            buffer[l++] = vows[Random_int_in_range(0,5)];
        
        for(int j=0; j<c; ++j)
            buffer[l++] = cons[Random_int_in_range(0,19)];
        
        if(0 == Random_int_in_range(0,3))
            buffer[l++] = cons[Random_int_in_range(0,19)];
    }
    
    buffer[0] -= 0x20;
    buffer[l] = '\0';
    
#else
    int length = Random_int_in_range(2, 20);
    
    for(int i=0; i<length; ++i)
        buffer[i] = Random_alpha_char();
    
    buffer[0] -= 0x20;
    buffer[length] = '\0';
#endif
    
    return [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
}


NSString *nameForType(TestDataType type) {
    switch(type) {
        case kData:    return @"data";   break;
        case kString:  return @"string"; break;
        case kGeneric:
        default:       return @"value";  break;
    }
}


id randomTestValue( TestDataType valueType, NSUInteger size ) {
    
    NSString *string = newRandomString(size);
    
    if(kData == valueType)
        return [string dataUsingEncoding:NSUTF8StringEncoding];
    
    return string;
}

id randomEncodedTestValue( TestDataType valueType, id *key ) {
    
    NULDBTestPerson *person = [NULDBTestPerson randomPerson];
    NSDictionary *plist = [person plistRepresentation];
    NSData *plistData = nil;
    id value;

    if(NULL != key) *key = [person uniqueID];

    if(valueType > 0) {
        int plistType = NSPropertyListBinaryFormat_v1_0;
        if(valueType > 1)
            plistType = NSPropertyListXMLFormat_v1_0;
        plistData = [NSPropertyListSerialization dataWithPropertyList:plist format:plistType options:0 error:NULL];
    }
    
    switch (valueType) {
            
        case kString:
            value = [[NSString alloc] initWithData:plistData encoding:NSUTF8StringEncoding];
            break;
            
        case kData:
            value = plistData;
            if(NULL != key) *key = [*key dataUsingEncoding:NSUTF8StringEncoding];
            break;
            
        case kGeneric:
        default:
            value = plist;
            break;
    }
    
    return value;
}

NSDictionary *randomTestDictionary( TestDataType contentType, NSUInteger count ) {
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:count];
    id key = nil;
    
    for(int i = 0; i<count; ++i)
        [dict setObject:randomEncodedTestValue(contentType, &key) forKey:key];
    
    return [dict copy];
}


@implementation NULDBTestUtilities

@end
