//
//  NULDBTestUtilities.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestUtilities.h"


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

@implementation NULDBTestUtilities

@end
