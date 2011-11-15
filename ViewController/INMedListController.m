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
#import "INEditMedViewController.h"
#import "INMedContainer.h"
#import "INMedTile.h"
#import "NSArray+NilProtection.h"


@interface INMedListController ()

@property (nonatomic, strong) INMedContainer *container;

- (void)showNewMedView:(id)sender;
- (void)setRecordButtonTitle:(NSString *)aTitle;

@end


@implementation INMedListController

@synthesize scrollView;
@synthesize record, medGroups;
@synthesize recordSelectButton, addMedButton;
@synthesize container;


- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		
	}
	return self;
}



#pragma mark - View lifecycle
- (void)loadView
{
    CGRect fullFrame = [[UIScreen mainScreen] applicationFrame];
	fullFrame.origin = CGPointZero;
	
	self.scrollView = [[UIScrollView alloc] initWithFrame:fullFrame];
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = scrollView;
	
	self.container = [[INMedContainer alloc] initWithFrame:fullFrame];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:container];
	
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
 *	Refreshes medication list
 */
- (void)refresh:(id)sender
{
	if (!record) {
		DLog(@"No record set, cannot refresh!");
		return;
	}
	
	// fetch this record's medications
	[record fetchReportsOfClass:[IndivoMedication class] callback:^(BOOL userDidCancel, NSString *errorMessage) {
		
		// error fetching medications
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to get medications"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		
		// successfully fetched medications, display
		else if (!userDidCancel) {
			NSArray *meds = [record documentsOfType:@"Medication"];
			DLog(@"Medications: %@", meds);
			NSMutableArray *tiles = [NSMutableArray arrayWithCapacity:[meds count]];
			for (IndivoMedication *med in meds) {
				INMedTile *tile = [INMedTile tileWithMedication:med];
				[tile addTarget:self action:@selector(editMedicationFrom:) forControlEvents:UIControlEventTouchUpInside];
				[tiles addObjectIfNotNil:tile];
			}
			
			[container showTiles:tiles];
			scrollView.contentSize = [container frame].size;
		}
	}];
}

/**
 *	Show the medication edit screen
 */
- (void)editMedicationFrom:(INMedTile *)medTile
{
	if (medTile.med) {
		INEditMedViewController *editView = [INEditMedViewController new];
		editView.med = medTile.med;
		[self.navigationController pushViewController:editView animated:YES];
	}
	else {
		DLog(@"The tile %@ has no associated medication", medTile);
	}
}

/**
 *	Show the add-medication screen
 */
- (void)showNewMedView:(id)sender
{
	if (self.record) {
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissModal:)];
		
		INNewMedViewController *newMed = [INNewMedViewController new];
		newMed.navigationItem.rightBarButtonItem = doneButton;
		newMed.listController = self;
		
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
			[self refresh:sender];
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
