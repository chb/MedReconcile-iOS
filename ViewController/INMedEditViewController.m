//
//  INMedEditViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedEditViewController.h"
#import "IndivoMedication.h"
#import "INButton.h"
#import "UIViewController+Utilities.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedEditViewController ()

- (void)loadMed;
- (void)updateNumDaysLabel;

- (void)keyboardWillShow:(NSNotification *)aNotification;
- (void)keyboardWillHide:(NSNotification *)aNotification;

@end


@implementation INMedEditViewController

@synthesize med;
@synthesize scrollView, agent, agentDesc, drug, drugDesc;
@synthesize dose, start, stop, numDays;
@synthesize instructions, prescriber;
@synthesize voidButton, replaceButton, stopButton;


- (id)init
{
	return [self initWithNibName:@"INMedEditViewController" bundle:nil];
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
	scrollView.frame = self.view.bounds;
	[self.view addSubview:scrollView];
	
	instructions.layer.borderColor = [[UIColor lightGrayColor] CGColor];
	instructions.layer.cornerRadius = 6.f;
	instructions.layer.borderWidth = 1.f;
	
	voidButton.buttonStyle = INButtonStyleDestructive;
	stopButton.buttonStyle = INButtonStyleDestructive;
	
	CGRect stopFrame = stopButton.frame;
	scrollView.contentSize = CGSizeMake([self.view bounds].size.width, stopFrame.origin.y + stopFrame.size.height + 20.f);
	
	// load med values
	[self loadMed];
}



#pragma mark - Medication Actions
/**
 *	Loads medication values into the fields
 */
- (void)loadMed
{
	if (med && [self isViewLoaded]) {
		agent.text = med.name.abbrev ? med.name.abbrev : med.name.text;
		agentDesc.text = med.name.text;
		drug.text = med.brandName.abbrev ? med.brandName.abbrev : med.brandName.text;
		drugDesc.text = med.brandName.text;
		
		INDate *startDate = med.prescription.on;
		INDate *stopDate = med.prescription.stopOn;
		start.text = startDate && ![startDate isNull] ? [startDate isoString] : @"";
		stop.text = stopDate && ![stopDate isNull] ? [stopDate isoString] : @"";
		
		// fill days selector
		[self updateNumDaysLabel];
	}
}


/**
 *	Saves current med values and dismisses the view controller
 */
- (void)saveMed:(id)sender
{
	med.name.abbrev = agent.text;
	med.brandName.abbrev = drug.text;
	
	IndivoPrescription *prescription = [IndivoPrescription new];
	prescription.nodeName = @"prescription";
	prescription.on = [INDate dateFromISOString:start.text];
	prescription.stopOn = [INDate dateFromISOString:stop.text];
	prescription.instructions = [INString newWithString:instructions.text];
	prescription.dispenseAsWritten = [INBool newNo];
	med.prescription = prescription;
	
	DLog(@"Med XML: %@", [med xml]);
	[med replace:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to update"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		else if (!userDidCancel) {
			[self dismiss:sender];
		}
	}];
}

/**
 *	Marks a medication voided
 */
- (IBAction)voidMed:(id)sender
{
	
}

/**
 *	duplicates the current med, populates the fields with its data and marks the original medication replaced by the duplicated one.
 *	@attention Does only actually replace the med once the duplicated medication is saved
 */
- (IBAction)replaceMed:(id)sender
{
	
}

/**
 *	Archives a medication
 */
- (IBAction)stopMed:(id)sender
{
	
}

/**
 *	Adjusts the stop date when the days toggle is operated
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
 *	Updates the num days label by comparing the text in the two input fields
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
	
	[UIView animateWithDuration:animDuration
					 animations:^{
						 scrollView.frame = target;
	}];
}

- (void)keyboardWillHide:(NSNotification *)aNotification
{
	CGRect target = self.view.bounds;
	
	NSDictionary *userInfo = [aNotification userInfo];
	NSTimeInterval animDuration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	[UIView animateWithDuration:animDuration
					 animations:^{
		scrollView.frame = target;
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
		[self loadMed];
	}
}


@end
