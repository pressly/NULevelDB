//
//  main.m
//  NULevelDB-TestApp
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NULevelDB_TestAppAppDelegate.h"

int main(int argc, char *argv[])
{
    int retVal = 0;
    @autoreleasepool {
        retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass([NULevelDB_TestAppAppDelegate class]));
    }
    return retVal;
}
