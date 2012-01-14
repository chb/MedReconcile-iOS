//
//  INMedEditViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INNewMedViewController.h"

@class IndivoMedication;
@class INButton;


/**
 *	This view controller allows to edit a medication and its prescription
 */
@interface INMedEditViewController : UIViewController <INNewMedViewControllerDelegate, UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, strong) IndivoMedication *med;

@property (nonatomic, assign) IBOutlet UIScrollView *scrollView;

@property (nonatomic, assign) IBOutlet UITextField *agent;
@property (nonatomic, assign) IBOutlet UILabel *agentDesc;
@property (nonatomic, assign) IBOutlet UITextField *drug;
@property (nonatomic, assign) IBOutlet UILabel *drugDesc;

@property (nonatomic, assign) IBOutlet UITextField *dose;
@property (nonatomic, assign) IBOutlet UITextField *start;
@property (nonatomic, assign) IBOutlet UITextField *stop;
@property (nonatomic, assign) IBOutlet UILabel *numDays;

@property (nonatomic, assign) IBOutlet UITextView *instructions;
@property (nonatomic, assign) IBOutlet UITextField *prescriber;

@property (nonatomic, assign) IBOutlet INButton *voidButton;
@property (nonatomic, assign) IBOutlet INButton *replaceButton;
@property (nonatomic, assign) IBOutlet INButton *stopButton;

- (void)saveMed:(id)sender;

- (IBAction)voidMed:(id)sender;
- (IBAction)replaceMed:(id)sender;
- (IBAction)stopMed:(id)sender;

- (IBAction)changeDays:(id)sender;


@end
