//
//  INViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/28/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedListController.h"
#import "INAppDelegate.h"
#import "IndivoServer.h"
#import "IndivoRecord.h"
#import "IndivoMedication.h"
#import "INNewMedViewController.h"


@interface INMedListController ()

- (void)showNewMedView:(id)sender;
- (void)setRecordButtonTitle:(NSString *)aTitle;
- (void)dismissModal:(id)sender;

@end


@implementation INMedListController

@synthesize record, medGroups;
@synthesize recordSelectButton, addMedButton;


- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		
	}
	return self;
}



#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// connect to indivo button
	self.recordSelectButton = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStyleBordered target:self action:@selector(selectRecord:)];
	self.navigationItem.leftBarButtonItem = recordSelectButton;
	
	// add button
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showNewMedView:)];
	addButton.enabled = NO;
	self.navigationItem.rightBarButtonItem = addButton;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
	
	self.recordSelectButton = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return SUPPORTED_ORIENTATION(interfaceOrientation);
}



#pragma mark - Medication Actions
/**
 *	Show the add-medication screen
 */
- (void)showNewMedView:(id)sender
{
	if (self.record) {
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissModal:)];
		
		INNewMedViewController *newMed = [INNewMedViewController new];
		newMed.navigationItem.rightBarButtonItem = doneButton;
		
		UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:newMed];
		if ([self respondsToSelector:@selector(presentViewController:animated:completion:)]) {		// iOS 5+ only
			[self presentViewController:navi animated:YES completion:NULL];
		}
		else {
			[self presentModalViewController:navi animated:YES];
		}
	}
	else {
		DLog(@"Tried to add a medication without active record");
	}
}



#pragma mark - Indivo
/**
 *	Connecting to the server retrieves the records of your users account
 */
- (void)selectRecord:(id)sender
{
	// create an activity indicator to show that something is happening
	UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	UIBarButtonItem *activityButton = [[UIBarButtonItem alloc] initWithCustomView:activityView];
	[activityButton setTarget:self];
	[activityButton setAction:@selector(cancelSelection:)];
	self.navigationItem.leftBarButtonItem = activityButton;
	[activityView startAnimating];
	
	// select record
	[APP_DELEGATE.indivo selectRecord:^(BOOL userDidCancel, NSString *errorMessage) {
		
		// there was an error selecting the record
		if (errorMessage) {
			[self setRecordButtonTitle:[record label]];
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to connect"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		
		// successfully selected record, fetch medications
		else if (!userDidCancel) {
			self.record = [APP_DELEGATE.indivo activeRecord];
			[self setRecordButtonTitle:[record label]];
			
			// fetch this record's medications
			[record fetchReportsOfClass:[IndivoMedication class] callback:^(BOOL userDidCancel, NSString *errorMessage) {
				
				// error fetching medications
				if (errorMessage) {
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to get medication"
																	message:errorMessage
																   delegate:nil
														  cancelButtonTitle:@"OK"
														  otherButtonTitles:nil];
					[alert show];
				}
				
				// successfully fetched medications, display
				else if (!userDidCancel) {
					//self.medGroups = [record documentsOfType:@"Medication"];
					// REFRESH DISPLAY
				}
			}];
		}
		
		// cancelled
		else {
			[self setRecordButtonTitle:[record label]];
		}
		
		self.navigationItem.rightBarButtonItem.enabled = (nil != self.record);
	}];
}

/**
 *	Cancels current connection attempt
 */
- (void)cancelSelection:(id)sender
{
	/// @todo cancel if still in progress
	[self setRecordButtonTitle:nil];
}

/**
 *	Reverts the navigation bar "connect" button
 */
- (void)setRecordButtonTitle:(NSString *)aTitle
{
	NSString *title = ([aTitle length] > 0) ? aTitle : @"Connect";
	UIBarButtonItem *connectButton = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleBordered target:self action:@selector(selectRecord:)];
	self.navigationItem.leftBarButtonItem = connectButton;
}

/**
 *	Dismiss current overlay view controller
 */
- (void)dismissModal:(id)sender
{
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {			// iOS 5+ only
		[self dismissViewControllerAnimated:YES completion:^{
			/// @todo Refresh med list
		}];
	}
	else {
		[self dismissModalViewControllerAnimated:YES];
		/// @todo Refresh med list
	}
}


@end
