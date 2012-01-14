//
//  INViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/28/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INNewMedViewController.h"

@class IndivoRecord;
@class INMedTile;


@interface INMedListController : UIViewController <INNewMedViewControllerDelegate>

@property (nonatomic, strong) IndivoRecord *record;
@property (nonatomic, strong) NSMutableArray *medGroups;

@property (nonatomic, strong) UIBarButtonItem *recordSelectButton;
@property (nonatomic, strong) UIBarButtonItem *addMedButton;

- (void)refresh:(id)sender;
- (void)dismissModalViewController:(id)sender;

- (void)setRecordButtonTitle:(NSString *)aTitle;


@end
