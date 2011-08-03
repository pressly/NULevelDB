//
//  NULDBSlice.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


#ifdef __cplusplus
class Slice;
#else
typedef void Slice;
#endif

@interface NULDBSlice : NSObject {
    Slice *slice;
}

@end
