//
//  INEditMedViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/15/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IndivoMedication;


@interface INEditMedViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) IndivoMedication *med;

@property (nonatomic, assign) IBOutlet UIScrollView *scroller;

@property (nonatomic, assign) IBOutlet UITextField *nameType;
@property (nonatomic, assign) IBOutlet UITextField *nameAbbrev;
@property (nonatomic, assign) IBOutlet UITextField *nameValue;
@property (nonatomic, assign) IBOutlet UITextField *nameText;
@property (nonatomic, assign) IBOutlet UITextField *brandedType;
@property (nonatomic, assign) IBOutlet UITextField *brandedAbbrev;
@property (nonatomic, assign) IBOutlet UITextField *brandedValue;
@property (nonatomic, assign) IBOutlet UITextField *brandedText;

- (IBAction)saveChanges:(id)sender;

@end
