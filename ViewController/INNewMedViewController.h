//
//  INNewMedViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/31/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZBarSDK.h"

@class INMedListController;
@class INNewMedViewController;
@class IndivoMedication;


@protocol INNewMedViewControllerDelegate <NSObject>

- (void)newMedController:(INNewMedViewController *)theController didSelectMed:(IndivoMedication *)aMed;

@optional
- (IndivoMedication *)initialMedForNewMedController:(INNewMedViewController *)theController;
- (NSString *)initialMedStringForNewMedController:(INNewMedViewController *)theController;
- (NSArray *)currentMedsForNewMedController:(INNewMedViewController *)theController;

@end


@interface INNewMedViewController : UITableViewController <UITextFieldDelegate, ZBarReaderDelegate>

@property (nonatomic, assign) id<INNewMedViewControllerDelegate> delegate;

- (void)loadSuggestionsFor:(NSString *)medString;
- (void)loadSuggestionsForMed:(IndivoMedication *)aMed;

@end
