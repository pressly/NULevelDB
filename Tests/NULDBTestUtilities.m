//
//  NULDBTestUtilities.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBTestUtilities.h"


NSString *NULDBRandomName( void ) {
    
    static char buffer[256];
    int length = Random_int_in_range(2, 40);
    
    for(int i=0; i<length; ++i)
        buffer[i] = Random_alpha_char();
    
    buffer[0] -= 0x20;
    buffer[length] = '\0';
    
    return [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
}

@implementation NULDBTestUtilities

@end
