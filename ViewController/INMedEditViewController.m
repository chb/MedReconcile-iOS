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


@interface INMedEditViewController ()

- (void)loadMed;

- (void)keyboardWillShow:(NSNotification *)aNotification;
- (void)keyboardWillHide:(NSNotification *)aNotification;

@end


@implementation INMedEditViewController

@synthesize med;
@synthesize scrollView, agent, agentDesc, drug, drugDesc;
@synthesize dose, start, stop, numDays, prescriber;
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
	self.voidButton.buttonStyle = INButtonStyleDestructive;
	self.stopButton.buttonStyle = INButtonStyleDestructive;
	
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
		
		start.text = med.dateStarted ? [med.dateStarted isoString] : @"";
		stop.text = med.dateStopped ? [med.dateStopped isoString] : @"";
	}
}

/**
 *	Saves current med values and dismisses the view controller
 */
- (void)saveMed:(id)sender
{
	med.name.abbrev = agent.text;
	med.brandName.abbrev = drug.text;
	
	med.dateStarted = [INDate dateFromISOString:start.text];
	med.dateStopped = [INDate dateFromISOString:stop.text];
	
	NSLog(@"%@", [med xml]);
	
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
	
}



#pragma mark - Keyboard Actions
- (void)keyboardWillShow:(NSNotification *)aNotification
{
	CGRect target = self.view.bounds;
	
	NSDictionary *userInfo = [aNotification userInfo];
	//NSTimeInterval animDuration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	NSValue *frameValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
	CGRect keyboardFrame = [self.view convertRect:[frameValue CGRectValue] fromView:self.view.window];
	CGRect intersect = CGRectIntersection(target, keyboardFrame);
	target.size.height = intersect.origin.y;
	
	scrollView.frame = target;
}

- (void)keyboardWillHide:(NSNotification *)aNotification
{
	
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
