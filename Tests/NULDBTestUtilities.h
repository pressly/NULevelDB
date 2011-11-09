//
//  NULDBTestUtilities.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


#define TEST_RANDOM_SEED 884432668

#define Random_int_in_range(_first_, _last_) ((int)(((float)random()/(float)LONG_MAX) * (_last_ - _first_) + _first_))

#define Random_printable_char() (Random_int_in_range(' ', '~'))
#define Random_alpha_char()     (Random_int_in_range('a', 'z'))
#define Random_digit_char()     (Random_int_in_range('0', '9'))

#define Random_ASCII()          (((float)random()/(float)INT_MAX) * ('~' - ' ') + ' ')

NSString *NULDBRandomName( void );


static inline NSString *randomString(NSUInteger length) {
    char *buffer = (char *)malloc(sizeof(char)*length);
    for (NSUInteger i=0; i<length; ++i) buffer[i] = Random_ASCII();
    return [[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

static inline NSString *uuidString( void ) {
    
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, uuid);
    NSString *result = (__bridge NSString *)string;

    CFRelease(string);
    CFRelease(uuid);

    return result;
}

@interface NULDBTestUtilities : NSObject

@end
