//
//  INEditMedViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/15/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INEditMedViewController.h"
#import "IndivoMedication.h"
#import "UIView+Utilities.h"


@interface INEditMedViewController ()

@property (nonatomic, assign) BOOL updateMedValuesAfterLoad;

- (void)updateMedValues;

- (void)keyboardWillShow:(NSNotification *)aNotification;
- (void)keyboardWillHide:(NSNotification *)aNotification;

@end


@implementation INEditMedViewController

@synthesize med;
@synthesize scroller;
@synthesize nameType, nameAbbrev, nameValue, nameText;
@synthesize brandedType, brandedAbbrev, brandedValue, brandedText;
@synthesize updateMedValuesAfterLoad;


- (id)init
{
	return [self initWithNibName:@"INEditMedViewController" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	}
	return self;
}



#pragma mark - Medication Actions
- (IBAction)saveChanges:(id)sender
{
	if (!med) {
		DLog(@"We don't have an assigned medication");
		return;
	}
	
	// name and brandedName
	med.name.type = nameType.text;
	med.name.abbrev = nameAbbrev.text;
	med.name.value = nameValue.text;
	med.name.text = nameText.text;
	med.brandName.type = brandedType.text;
	med.brandName.abbrev = brandedAbbrev.text;
	med.brandName.value = brandedValue.text;
	med.brandName.text = brandedText.text;
	
	// push
	[med replace:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Update Failed"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"Too Bad"
												  otherButtonTitles:nil];
			[alert show];
		}
		else if (!userDidCancel) {
			[self.navigationController popViewControllerAnimated:YES];
		}
	}];
}



#pragma mark - Medication Display
- (void)setMed:(IndivoMedication *)newMed
{
	if (newMed != med) {
		med = newMed;
		
		if ([self isViewLoaded]) {
			[self updateMedValues];
		}
		else {
			updateMedValuesAfterLoad = YES;
		}
	}
}

/**
 *	Updates the view with values from our medication
 */
- (void)updateMedValues
{
	DLog(@"%@", [med xml]);
	
	nameType.text = med.name.type;
	nameAbbrev.text = med.name.abbrev;
	nameValue.text = med.name.value;
	nameText.text = med.name.text;
	brandedType.text = med.brandName.type;
	brandedAbbrev.text = med.brandName.abbrev;
	brandedValue.text = med.brandName.value;
	brandedText.text = med.brandName.text;
}



#pragma mark - View Lifecycle
- (void)viewDidLoad
{
	if (updateMedValuesAfterLoad) {
		updateMedValuesAfterLoad = NO;
		[self updateMedValues];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	CGFloat lowest = 0.f;
	for (UIView *sub in [scroller subviews]) {
		CGRect subFrame = sub.frame;
		lowest = fmaxf(lowest, subFrame.origin.y + subFrame.size.height);
	}
	
	CGSize scrollerSize = CGSizeMake(320.f, lowest + 20.f);
	scroller.contentSize = scrollerSize;
}



#pragma mark - UITextFieldDelegate
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	CGRect fieldFrame = [scroller convertRect:textField.frame fromView:[textField superview]];
	[scroller scrollRectToVisible:fieldFrame animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}



#pragma mark - Keyboard
- (void)keyboardWillShow:(NSNotification *)aNotification
{
	CGRect boardRect = [[[aNotification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	boardRect = [self.view convertRect:boardRect fromView:self.view.window];
	CGRect overlay = CGRectIntersection(boardRect, self.view.bounds);
	
	NSTimeInterval duration = [[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	[UIView animateWithDuration:duration
					 animations:^{
						 CGRect myFrame = self.view.frame;
						 myFrame.size.height = overlay.origin.y;
						 self.view.frame = myFrame;
					 }
					 completion:^(BOOL finished) {
						 
						 // make sure first responder is visible
						 UIView *first = [scroller findFirstResponder];
						 if (first) {
							 CGRect firstFrame = [scroller convertRect:first.frame fromView:[first superview]];
							 [scroller scrollRectToVisible:firstFrame animated:YES];
						 }
					 }];
}

- (void)keyboardWillHide:(NSNotification *)aNotification
{
	CGRect boardRect = [[[aNotification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	
	CGRect myFrame = self.view.frame;
	myFrame.size.height += boardRect.size.height;
	self.view.frame = myFrame;
}


@end
