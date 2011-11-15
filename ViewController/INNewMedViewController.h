//
//  INNewMedViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/31/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class INMedListController;


@interface INNewMedViewController : UITableViewController <UITextFieldDelegate>

@property (nonatomic, assign) INMedListController *listController;				///< Used to refresh the list after a med was added

- (void)loadSuggestionsFor:(NSString *)medString;

@end
