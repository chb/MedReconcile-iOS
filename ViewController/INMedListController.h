//
//  INViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/28/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INNewMedViewController.h"
#import "INEditMedViewController.h"

@class IndivoRecord;
@class INMedTile;


@interface INMedListController : UIViewController <INNewMedViewControllerDelegate, INEditMedViewControllerDelegate>

@property (nonatomic, strong) IndivoRecord *record;
@property (nonatomic, strong) NSMutableArray *medications;

@property (nonatomic, strong) UIBarButtonItem *recordSelectButton;
@property (nonatomic, strong) UISegmentedControl *sortSelector;

- (void)processMedicationsAndRefresh:(BOOL)refresh;

- (void)reloadList:(id)sender;
- (void)dismissPresentedViewControllerAnimated:(BOOL)animated;
- (void)indicateActivity:(BOOL)active;


@end
