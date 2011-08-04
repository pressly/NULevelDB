//
//  NULDBTestUtilities.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-03.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


#define Random_int_in_range(_first_, _last_) ((int)(((float)random()/(float)INT_MAX) * (_last_ - _first_) + _first_))

#define Random_printable_char() (Random_int_in_range(' ', '~'))
#define Random_alpha_char() (Random_int_in_range('a', 'z'))
#define Random_digit_char() (Random_int_in_range('0', '9'))

NSString *NULDBRandomName( void );

@interface NULDBTestUtilities : NSObject

@end
