//
//  INMedEditViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedEditViewController.h"
#import "INButton.h"
#import "UIViewController+Utilities.h"


@implementation INMedEditViewController

@synthesize med;
@synthesize agent, agentDesc, drug, drugDesc;
@synthesize dose, start, stop, numDays, prescriber;
@synthesize voidButton, replaceButton, stopButton;


- (id)init
{
	return [self initWithNibName:@"INMedEditViewController" bundle:nil];
}


- (void)viewDidLoad
{
	self.voidButton.buttonStyle = INButtonStyleDestructive;
	self.stopButton.buttonStyle = INButtonStyleDestructive;
}



#pragma mark - Medication Actions
/**
 *	Saves current med values and dismisses the view controller
 */
- (void)saveMed:(id)sender
{
	[self dismiss:sender];
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


@end
