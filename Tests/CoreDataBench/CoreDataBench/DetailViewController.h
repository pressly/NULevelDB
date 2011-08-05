//
//  DetailViewController.h
//  CoreDataBench
//
//  Created by Brent Gulanowski on 11-08-05.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;

@property (strong, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end
