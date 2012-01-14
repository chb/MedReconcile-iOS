//
//  INEditMedViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INNewMedViewController.h"

@class IndivoMedication;
@class INButton;
@class INEditMedViewController;


@protocol INEditMedViewControllerDelegate <NSObject>

- (void)editMedController:(INEditMedViewController *)theController didActOnMed:(IndivoMedication *)aMed;
- (void)editMedController:(INEditMedViewController *)theController didReplaceMed:(IndivoMedication *)aMed withMed:(IndivoMedication *)newMed;
- (void)editMedController:(INEditMedViewController *)theController didVoidMed:(IndivoMedication *)aMed;

@end


/**
 *	This view controller allows to edit a medication and its prescription
 */
@interface INEditMedViewController : UIViewController <INNewMedViewControllerDelegate, UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, assign) id <INEditMedViewControllerDelegate> delegate;
@property (nonatomic, strong) IndivoMedication *med;

@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;

@property (nonatomic, strong) IBOutlet UIView *agentContainer;
@property (nonatomic, strong) IBOutlet UIView *drugContainer;
@property (nonatomic, strong) IBOutlet UIView *buttonContainer;

@property (nonatomic, assign) IBOutlet UITextField *agent;
@property (nonatomic, assign) IBOutlet UILabel *agentDesc;
@property (nonatomic, assign) IBOutlet UILabel *agentNameHint;

@property (nonatomic, assign) IBOutlet UITextField *drug;
@property (nonatomic, assign) IBOutlet UILabel *drugDesc;
@property (nonatomic, assign) IBOutlet UILabel *drugNameHint;

@property (nonatomic, assign) IBOutlet UITextField *dose;
@property (nonatomic, assign) IBOutlet UITextField *start;
@property (nonatomic, assign) IBOutlet UITextField *stop;
@property (nonatomic, assign) IBOutlet UILabel *numDays;

@property (nonatomic, assign) IBOutlet UITextView *instructions;
@property (nonatomic, assign) IBOutlet UITextField *prescriber;

@property (nonatomic, assign) IBOutlet INButton *voidButton;
@property (nonatomic, assign) IBOutlet INButton *replaceButton;
@property (nonatomic, assign) IBOutlet INButton *mainButton;

- (void)saveMed:(id)sender;
- (void)archiveMed:(id)sender;
- (void)unarchiveMed:(id)sender;
- (void)unvoidMed:(id)sender;

- (IBAction)voidMed:(id)sender;
- (IBAction)replaceMed:(id)sender;

- (IBAction)changeDays:(id)sender;


@end
