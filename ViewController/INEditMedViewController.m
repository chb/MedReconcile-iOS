//
//  INEditMedViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INEditMedViewController.h"
#import "IndivoDocuments.h"
#import "INButton.h"
#import "UIViewController+Utilities.h"
#import "INAppDelegate.h"
#import "UIView+Utilities.h"
#import <QuartzCore/QuartzCore.h>


@interface INEditMedViewController ()

- (void)loadMed;
- (void)updateNumDaysLabel;

- (void)keyboardWillShow:(NSNotification *)aNotification;
- (void)keyboardWillHide:(NSNotification *)aNotification;

@end


@implementation INEditMedViewController

@synthesize delegate, med;
@synthesize scrollView, agentContainer, drugContainer, buttonContainer;
@synthesize agent, agentDesc, agentNameHint, drug, drugDesc, drugNameHint;
@synthesize details, quantity, start, stop, numDays;
@synthesize instructions, prescriber;
@synthesize voidButton, replaceButton, mainButton;


#pragma mark -
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


- (void)viewDidLoad
{
	CGRect myBounds = [self.view bounds];
	scrollView.frame = myBounds;
	[self.view addSubview:scrollView];
	[scrollView addSubview:agentContainer];
	[scrollView addSubview:drugContainer];
	
	// styling
	
	instructions.layer.borderColor = [[UIColor lightGrayColor] CGColor];
	instructions.layer.cornerRadius = 6.f;
	instructions.layer.borderWidth = 1.f;
	
	voidButton.buttonStyle = INButtonStyleDestructive;
	mainButton.buttonStyle = INButtonStyleDestructive;
	
	// setup the control button strip sticking to the lower part of the screen
	CGRect buttonFrame = buttonContainer.frame;
	buttonFrame.origin.x = 0.f;
	buttonFrame.origin.y = myBounds.size.height - buttonFrame.size.height;
	buttonFrame.size.width = myBounds.size.width;
	buttonContainer.frame = buttonFrame;
	[self.view addSubview:buttonContainer];
	
	// load med values
	[self loadMed];
}


- (void)layoutAnimated:(BOOL)animated
{
	DLog(@"layout animated: %d", animated);
	CGSize mySize = [self.view bounds].size;
	CGFloat y = 20.f;
	CGSize max = CGSizeMake(mySize.width - 2*20.f, CGFLOAT_MAX);
	
	// ** drug area
	CGRect frame1 = agentContainer.frame;
	frame1.origin.y = 0.f;
	
	if (!agentNameHint.hidden) {
		CGSize need = [agentNameHint.text sizeWithFont:agentNameHint.font constrainedToSize:max lineBreakMode:UILineBreakModeWordWrap];
		agentNameHint.frame = CGRectMake(20.f, y, max.width, need.height);
		y += need.height + 2.f;
	}
	CGRect agentFrame = agent.frame;
	agentFrame.origin.y = y;
	agentFrame.size.width = max.width;
	agent.frame = agentFrame;
	y = agentFrame.origin.y + agentFrame.size.height;
	
	if (!agentDesc.hidden) {
		y += 8.f;
		CGSize need = [agentDesc.text sizeWithFont:agentDesc.font constrainedToSize:max lineBreakMode:UILineBreakModeWordWrap];
		agentDesc.frame = CGRectMake(20.f, y, max.width, need.height);
		y += need.height;
	}
	frame1.size.height = y;
	
	// ** prescription area
	CGRect frame2 = drugContainer.frame;
	frame2.origin.y = frame1.size.height;
	y = [drug frame].origin.y + [drug frame].size.height;
	if (!drugDesc.hidden) {
		y += 8.f;
		CGSize need = [drugDesc.text sizeWithFont:drugDesc.font constrainedToSize:max lineBreakMode:UILineBreakModeWordWrap];
		drugDesc.frame = CGRectMake(20.f, y, max.width, need.height);
		y += need.height;
	}
	y += 20.f;
	CGRect detailRect = details.frame;
	detailRect.origin.y = y;
	details.frame = detailRect;
	y += detailRect.size.height;
	frame2.size.height = y;
	
	// button area
	CGSize buttons = [buttonContainer bounds].size;
	
	[mainButton sizeToFit];
	CGRect aFrame = mainButton.frame;
	aFrame.origin.x = buttons.width - 20.f - aFrame.size.width;
	mainButton.frame = aFrame;
	
	if (!replaceButton.hidden) {
		[replaceButton sizeToFit];
		aFrame.size.width = [replaceButton frame].size.width;
		aFrame.origin.x -= aFrame.size.width + 8.f;
		replaceButton.frame = aFrame;
	}
	
	if (!voidButton.hidden) {
		[voidButton sizeToFit];
		CGRect voidFrame = voidButton.frame;
		if (voidFrame.size.width > 0.f && aFrame.origin.x - 8.f < 20.f + voidFrame.size.width) {
			DLog(@"PROBLEM, the buttons are crammed!");
		}
		voidFrame.origin.x = 20.f;
		voidButton.frame = voidFrame;
	}
	
	[UIView animateWithDuration:(animated ? 0.2 : 0.0)
					 animations:^{
						 agentContainer.frame = frame1;
						 drugContainer.frame = frame2;
					 }];
	
	scrollView.contentSize = CGSizeMake([self.view bounds].size.width, frame2.origin.y + frame2.size.height + buttons.height);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return SUPPORTED_ORIENTATION(interfaceOrientation);
}



#pragma mark - Medication Actions
/**
 *  Loads medication values into the fields if we have a med and the view is loaded. Will in any case call layoutAnimated:NO.
 */
- (void)loadMed
{
	if (med && [self isViewLoaded]) {
		agent.text = med.drugName.title;
		//agentDesc.text = [med medicationCodedName];
		agentDesc.text = [med displayName];
		drug.text = med.drugName.title;
		//drugDesc.text = [med prescriptionCodedName];
		drugDesc.text = [med displayName];
		
		quantity.text = [med.quantity.value stringValue];
		
		// date started and stopped
		INDate *startDate = med.startDate;
		if (!startDate) {
			startDate = [INDate dateWithDate:[NSDate date]];
		}
		INDateTime *stopDate = med.endDate;
		
		start.text = startDate && ![startDate isNull] ? [startDate isoString] : @"";
		stop.text = stopDate && ![stopDate isNull] ? [stopDate isoString] : @"";
		
		// fill days selector
		[self updateNumDaysLabel];
		
		// update hints and buttons according to status
		[mainButton removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
		switch (med.documentStatus) {
			case INDocumentStatusActive:
				agentNameHint.hidden = NO;
				drugNameHint.hidden = NO;
				drugNameHint.text = @"Use \"Replace...\" to change the medication";
				
				[mainButton setTitle:@"Stop" forState:UIControlStateNormal];
				[mainButton addTarget:self action:@selector(archiveMed:) forControlEvents:UIControlEventTouchUpInside];
				mainButton.buttonStyle = INButtonStyleDestructive;
				replaceButton.hidden = NO;
				voidButton.hidden = NO;
				break;
			case INDocumentStatusArchived:
				agentNameHint.hidden = NO;
				drugNameHint.hidden = YES;
				
				[mainButton setTitle:@"Unarchive" forState:UIControlStateNormal];
				[mainButton addTarget:self action:@selector(unarchiveMed:) forControlEvents:UIControlEventTouchUpInside];
				mainButton.buttonStyle = INButtonStyleMain;
				replaceButton.hidden = YES;
				voidButton.hidden = YES;
				break;
			case INDocumentStatusVoid:
				agentNameHint.hidden = NO;
				drugNameHint.hidden = YES;
				
				[mainButton setTitle:@"Unvoid" forState:UIControlStateNormal];
				[mainButton addTarget:self action:@selector(unvoidMed:) forControlEvents:UIControlEventTouchUpInside];
				mainButton.buttonStyle = INButtonStyleMain;
				replaceButton.hidden = YES;
				voidButton.hidden = YES;
				break;
			case INDocumentStatusUnknown:
			default:
				agentNameHint.hidden = YES;
				drugNameHint.hidden = NO;
				drugNameHint.text = @"How you want to name the prescription";
				
				[mainButton setTitle:@"Add" forState:UIControlStateNormal];
				[mainButton addTarget:self action:@selector(saveMed:) forControlEvents:UIControlEventTouchUpInside];
				mainButton.buttonStyle = INButtonStyleAccept;
				replaceButton.hidden = YES;
				voidButton.hidden = YES;
				break;
		}
	}
	
	[self layoutAnimated:NO];
}



/**
 *  Marks a medication voided
 */
- (IBAction)voidMed:(id)sender
{
	[med void:YES forReason:@"no reason specified" callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Voiding Failed"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		else if (!userDidCancel) {
			[delegate editMedController:self didVoidMed:med];
		}
	}];
}

/**
 *  duplicates the current med, populates the fields with its data and marks the original medication replaced by the duplicated one.
 *  @attention Does only actually replace the med once the duplicated medication is saved
 */
- (IBAction)replaceMed:(id)sender
{
	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissModalViewController:)];
	
	INNewMedViewController *newMed = [INNewMedViewController new];
	newMed.navigationItem.rightBarButtonItem = doneButton;
	newMed.delegate = self;
	
	UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:newMed];
	[self presentViewController:navi animated:YES completion:NULL];
}

/**
 *  Actions for the main button
 */

- (void)saveMed:(id)sender
{
	if (!med.record) {
		med.record = APP_DELEGATE.indivo.activeRecord;
	}
	
	// update display names
	if (!med.drugName) {
		med.drugName = [INCodedValue new];
	}
	med.drugName.title = agent.text;

	// update details
//	IndivoPrescription *prescription = med.prescription;
//	if (!prescription) {
//		prescription = [IndivoPrescription new];
//	}
//	startDate = [INDate dateFromISOString:start.text];
//	endDate = [INDate dateFromISOString:stop.text];
//	prescription.instructions = [INString newWithString:instructions.text];
//	prescription.dispenseAsWritten = [INBool newNo];
//	med.prescription = prescription;
	
	if (!med.quantity) {
		med.quantity = [INUnitValue new];			// must be present for the current scheme to validate
	}
	
	[med replace:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {		// "replace" will call "push" if the med is new
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to update"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		else if (!userDidCancel) {
			[delegate editMedController:self didActOnMed:med];
		}
	}];
}

- (void)archiveMed:(id)sender
{
	
}

- (void)unarchiveMed:(id)sender
{
	[med archive:NO forReason:@"ractivating" callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unarchiving Failed"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		else if (!userDidCancel) {
			[delegate editMedController:self didActOnMed:med];
		}
	}];
}

- (void)unvoidMed:(id)sender
{
	[med void:NO forReason:@"unvoiding" callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unvoiding Failed"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		else if (!userDidCancel) {
			[delegate editMedController:self didActOnMed:med];
		}
	}];
}



/**
 *  Adjusts the stop date when the days toggle is operated
 */
- (IBAction)changeDays:(id)sender
{
	UISegmentedControl *control = (UISegmentedControl *)sender;			///< @todo This is... dirty...
	
	NSDate *from = [INDate parseDateFromISOString:start.text];
	if (!from) {
		from = [NSDate date];
		start.text = [INDate isoStringFrom:from];
	}
	NSDate *until = [INDate parseDateFromISOString:stop.text];
	NSInteger currentDays = 0;
	
	if (from && until) {
		NSCalendar *myCalendar = [NSCalendar currentCalendar];
		currentDays = [[myCalendar components:NSDayCalendarUnit fromDate:from toDate:until options:0] day];
	}
	
	// decrease or increase by one day
	if (0 == control.selectedSegmentIndex) {
		currentDays--;
	}
	else {
		currentDays++;
	}
	
	until = (currentDays >= 0) ? [from dateByAddingTimeInterval:currentDays * 24 * 3600] : nil;
	stop.text = until ? [INDate isoStringFrom:until] : @"";
	
	// update
	[self updateNumDaysLabel];
}

/**
 *  Updates the num days label by comparing the text in the two input fields
 */
- (void)updateNumDaysLabel
{
	NSDate *from = [INDate parseDateFromISOString:start.text];
	NSDate *until = [INDate parseDateFromISOString:stop.text];
	
	NSString *numDaysText = @"";
	if (from && until) {
		NSCalendar *myCalendar = [NSCalendar currentCalendar];
		NSInteger day = [[myCalendar components:NSDayCalendarUnit fromDate:from toDate:until options:0] day];
		if (day >= 0) {
			numDaysText = (1 == day) ? @"1 day" : [NSString stringWithFormat:@"%d days", day];
		}
	}
	numDays.text = numDaysText;
}



#pragma mark - INNewMedViewControllerDelegate
- (IndivoMedication *)initialMedForNewMedController:(INNewMedViewController *)theController
{
	return self.med;
}

- (void)newMedController:(INNewMedViewController *)theController didSelectMed:(IndivoMedication *)aMed;
{
	DLog(@"Got %@", aMed);
}


/**
 *  Dismiss current overlay view controller
 */
- (void)dismissModalViewController:(id)sender
{
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {			// iOS 5+ only
		[self dismissViewControllerAnimated:YES completion:NULL];
	}
	else {
		[self dismissModalViewControllerAnimated:YES];
	}
}



#pragma mark - Keyboard Actions
- (void)keyboardWillShow:(NSNotification *)aNotification
{
	CGRect target = self.view.bounds;
	
	NSDictionary *userInfo = [aNotification userInfo];
	NSTimeInterval animDuration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	NSValue *frameValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
	CGRect keyboardFrame = [self.view convertRect:[frameValue CGRectValue] fromView:self.view.window];
	CGRect intersect = CGRectIntersection(target, keyboardFrame);
	target.size.height = intersect.origin.y;
	
	CGRect buttonFrame = buttonContainer.frame;
	buttonFrame.origin.y = target.size.height - buttonFrame.size.height;
	
	[UIView animateWithDuration:animDuration
					 animations:^{
						 scrollView.frame = target;
						 buttonContainer.frame = buttonFrame;
					 }
					 completion:^(BOOL finished) {
						 
						 // make sure first responder is visible
						 UIView *first = [scrollView findFirstResponder];
						 if (first) {
							 CGRect firstFrame = [scrollView convertRect:first.frame fromView:[first superview]];
							 firstFrame.origin.y += buttonFrame.size.height;		// to avoid hitting the button container
							 firstFrame.origin.y += 8.f;							// some padding
							 firstFrame.size.height = fminf(firstFrame.size.height, 70.f);		// to hack around the too high textView. Problem if there's already text...
							 [scrollView scrollRectToVisible:firstFrame animated:YES];
						 }
					 }];
}

- (void)keyboardWillHide:(NSNotification *)aNotification
{
	CGRect target = self.view.bounds;
	
	CGRect buttonFrame = buttonContainer.frame;
	buttonFrame.origin.y = target.size.height - buttonFrame.size.height;
	
	NSDictionary *userInfo = [aNotification userInfo];
	NSTimeInterval animDuration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	[UIView animateWithDuration:animDuration
					 animations:^{
						 scrollView.frame = target;
						 buttonContainer.frame = buttonFrame;
					 }];
}



#pragma mark - Textfield Delegate
- (BOOL)textField:(UITextField *)aTextField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	if (start == aTextField || stop == aTextField) {
		[self performSelector:@selector(updateNumDaysLabel) withObject:nil afterDelay:0.0];
	}
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return NO;
}

- (BOOL)textView:(UITextView *)aTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
	if (instructions == aTextView) {
		if ([text isEqualToString:@"\n"]) {
			[instructions resignFirstResponder];
			return NO;
		}
	}
	return YES;
}




#pragma mark - KVC
- (void)setMed:(IndivoMedication *)aMed
{
	if (aMed != med) {
		med = aMed;
		
		if (!med.startDate) {
			med.startDate = [INDateTime dateWithDate:[NSDate date]];		// to make the current scheme validate. We don't use this property.
		}
		[self loadMed];
	}
}


@end
