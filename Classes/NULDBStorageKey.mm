//
//  NULDBStorageKey.cpp
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-10.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#include <iostream>

#include "NULDBStorageKey.h"
#import "NULDBDB.h"


@interface NULDBDB ()
- (NSUInteger)classCodeForObject:(id)object;
- (NSUInteger)objectCodeForObject:(id)object;
@end


namespace NULDB {
    
    const char StorageKey::keyTypes[] = {'O', 'I', 'P', 'C'};

    const Slice CountersKey = Slice("NULDBCounters", sizeof("NULDBCounters"));


    BOOL StorageKey::valid(Slice *slice) {
        
        if(slice->size() < sizeof(StorageKey))
            return NO;
        
        std::string data = slice->ToString();
        
        if(data[0] != 'N' || data[1] != 'U')
            return NO;
        
        // This doesn't verify the property value code, object code, class code, array code, property index or array index
        for(int i=0; i<4; ++i)
            if(data[2] == keyTypes[i])
                return YES;
        
        return NO;
    }
    
    
    StorageKey::StorageKey(Slice &slice) : prefix1('\0'), prefix2('\0') {
        
        struct temp {
            char c[4];
            NSUInteger u[2];
        } temp;
        
        memcpy(&temp, slice.data(), sizeof(temp));
        
        assert(temp.c[0] == 'N');
        assert(temp.c[1] == 'U');
        
        keyType = temp.c[2];
        valType = temp.c[3];
        a = temp.u[0];
        b = temp.u[1];
    }
    
    
    ObjectKey::ObjectKey(NULDBDB *db, id object) : StorageKey('O', ' ') {
        a = [db classCodeForObject:object];
        b = [db objectCodeForObject:object];
    }


    ClassKey::ClassKey(NULDBDB *db, id object) : StorageKey('C', ' ') {
        a = [db classCodeForObject:object];
    }


    ClassDescription::ClassDescription(Slice &slice) {
        
        NSString *temp = [[NSString alloc] initWithUTF8String:slice.ToString().c_str()];
        NSUInteger sepLoc = [temp rangeOfString:@"|"].location;
        
        className = [temp substringToIndex:sepLoc];
        properties = [[temp substringFromIndex:sepLoc+1] componentsSeparatedByString:@","];
    }
    
    ArrayToken::ArrayToken(Slice &slice) {
        NSUInteger temp;
        memcpy(&temp, slice.data(), sizeof(temp));
        name = temp;
    }
    
    Slice ClassDescription::slice(void) {
        
        NSString *temp = [NSString stringWithFormat:@"%@|%@", className, [properties componentsJoinedByString:@","]];
        
        return Slice([temp UTF8String]);
    }
    
    
    const char StringKey::PREFIX[6] = { 'N', 'U', 'L', 'D', 'B', ':' };
    
    const char getKeyType(Slice &slice) {
        
        if(!StorageKey::valid(slice))
            return '\0';
        
        return slice.data()[3];
    }

}
