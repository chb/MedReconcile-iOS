//
//  INViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/28/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedListController.h"
#import <QuartzCore/QuartzCore.h>
#import "INAppDelegate.h"
#import "IndivoServer.h"
#import "IndivoRecord.h"
#import "IndivoDocuments.h"
#import "IndivoMedicationGroup.h"

#import "INMedicationProcessor.h"

#import "INEditMedViewController.h"
#import "INMedContainer.h"
#import "INMedTile.h"
#import "INMedDetailTile.h"
#import "INButton.h"
#import "NSArray+NilProtection.h"
#import "UIView+Utilities.h"


@interface INMedListController ()

@property (nonatomic, strong) INMedContainer *container;
@property (nonatomic, strong) INMedTile *activeTile;

@property (nonatomic, assign) BOOL showVoid;

@property (nonatomic, strong) UIView *controlView;
@property (nonatomic, strong) INButton *detailToggle;
@property (nonatomic, strong) UISlider *timeSlider;
@property (nonatomic, strong) UILabel *timeSliderInfo;
@property (nonatomic, strong) UILabel *timeSliderFloater;
@property (nonatomic, strong) NSDate *minStopDate;

- (void)refreshListAnimated:(BOOL)animated;
- (void)showNewMedView:(id)sender;

- (void)sortSelectorDidChange:(id)sender;
- (void)timeSliderDidChange:(id)sender;
- (void)toggleControlPane:(id)sender;
- (void)showControlPaneAnimated:(BOOL)animated;
- (void)hideControlPaneAnimated:(BOOL)animated;
- (void)hideTimeSliderFloater;
- (void)voidButtonTapped:(id)sender;

- (void)documentsDidChange:(NSNotification *)aNotification;
- (void)setRecordButtonTitle:(NSString *)aTitle;

@end


@implementation INMedListController

@synthesize record, medications;
@synthesize recordSelectButton, sortSelector;
@synthesize container, activeTile;
@synthesize showVoid;
@synthesize controlView, detailToggle, timeSlider, timeSliderInfo, timeSliderFloater, minStopDate;


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:INRecordDocumentsDidChangeNotification object:nil];
}

- (id)init
{
	if ((self = [super initWithNibName:nil bundle:nil])) {
		self.medications = [NSMutableArray array];
		self.minStopDate = [NSDate date];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentsDidChange:) name:INRecordDocumentsDidChangeNotification object:nil];
	}
	return self;
}



#pragma mark - View lifecycle
- (void)loadView
{
    CGRect fullFrame = [[UIScreen mainScreen] applicationFrame];
	fullFrame.origin = CGPointZero;
	self.view = [[UIView alloc] initWithFrame:fullFrame];
	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	
	// the background logo
	UIImage *bgImage = [UIImage imageNamed:@"IndivoHealth.png"];
	UIImageView *bgView = [[UIImageView alloc] initWithImage:bgImage];
	bgView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.view addSubview:bgView];
	[bgView centerInSuperview];
	CGRect bgFrame = bgView.frame;
	bgFrame.origin.y -= bgFrame.size.height;
	bgView.frame = bgFrame;
	
	// add the container
	fullFrame.size.height -= [self.controlView frame].size.height;
	self.container = [[INMedContainer alloc] initWithFrame:fullFrame];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	container.viewController = self;
	[self.view addSubview:container];
	
	// add the control view
	[self.view addSubview:self.controlView];
	
	// navigation items
	self.recordSelectButton = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStyleBordered target:self action:@selector(selectRecord:)];
	self.navigationItem.leftBarButtonItem = recordSelectButton;
	
	self.sortSelector = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Start", @"Stop", @"A-Z", nil]];
	sortSelector.segmentedControlStyle = UISegmentedControlStyleBar;
	sortSelector.selectedSegmentIndex = 0;
	sortSelector.enabled = NO;
	[sortSelector addTarget:self action:@selector(sortSelectorDidChange:) forControlEvents:UIControlEventValueChanged];
	//self.navigationItem.titleView = sortSelector;			// only show if we have a record
	
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



#pragma mark - Display Control Actions
- (void)sortSelectorDidChange:(id)sender
{
	[self refreshListAnimated:YES];
}

- (void)timeSliderDidChange:(id)sender
{
	[container removeDetailTileAnimated:YES];
	
	// cancel previous timeout
	if (timeSliderFloater) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTimeSliderFloater) object:nil];
	}
	
	if (1.f == timeSlider.value) {
		self.minStopDate = [NSDate date];
		self.timeSliderInfo.text = @"Current";
		self.timeSliderFloater.text = @"Current";
	}
	
	// we calculate the timepoint of "frac" between now and -10 years (age of patient would be desireable)
	else if (0.f != timeSlider.value) {
		CGFloat frac = powf(1.f - timeSlider.value, 3);
		NSDate *now = [NSDate date];
		self.minStopDate = [now dateByAddingTimeInterval:-frac * (10*365.25*24*3600)];
		
		NSDateFormatter *df = [[NSDateFormatter alloc] init];
		df.dateStyle = NSDateFormatterMediumStyle;
		df.timeStyle = NSDateFormatterNoStyle;
		self.timeSliderInfo.text = [df stringFromDate:minStopDate];
		self.timeSliderFloater.text = [df stringFromDate:minStopDate];
	}
	else {
		self.minStopDate = nil;
		self.timeSliderInfo.text = @"All";
		self.timeSliderFloater.text = @"All";
	}
	[self refreshListAnimated:YES];
	
	// attach timeslider and set timeout to hide it again
	timeSliderFloater.layer.opacity = 1.f;
	[self.view addSubview:timeSliderFloater];
	[timeSliderFloater centerInSuperview];
	[self performSelector:@selector(hideTimeSliderFloater) withObject:nil afterDelay:1.5];
}

- (void)hideTimeSliderFloater
{
	[UIView animateWithDuration:kINMedContainerAnimDuration
					 animations:^{
						 timeSliderFloater.layer.opacity = 0.f;
					 }
					 completion:^(BOOL finished) {
						 [timeSliderFloater removeFromSuperview];
						 //self.timeSliderFloater = nil;
					 }];
}

- (void)toggleControlPane:(id)sender
{
	if ([controlView frame].size.height > 50.f) {
		[self hideControlPaneAnimated:(nil != sender)];
	}
	else {
		[self showControlPaneAnimated:(nil != sender)];
	}
}

- (void)showControlPaneAnimated:(BOOL)animated
{
	CGSize mySize = [self.view bounds].size;
	CGRect containerFrame = container.frame;
	CGRect controlFrame = controlView.frame;
	
	controlFrame.size.height = 100.f;
	containerFrame.size.height = mySize.height - controlFrame.size.height;
	controlFrame.origin.y = containerFrame.size.height;
	
	if (animated) {
		[UIView animateWithDuration:0.2
						 animations:^{
							 container.frame = containerFrame;
							 controlView.frame = controlFrame;
						 }];
	}
	else {
		container.frame = containerFrame;
		controlView.frame = controlFrame;
	}
	
	[detailToggle setImage:[UIImage imageNamed:@"hide.png"] forState:UIControlStateNormal];
}

- (void)hideControlPaneAnimated:(BOOL)animated
{
	CGSize mySize = [self.view bounds].size;
	CGRect containerFrame = container.frame;
	CGRect controlFrame = controlView.frame;
	
	controlFrame.size.height = 50.f;
	containerFrame.size.height = mySize.height - controlFrame.size.height;
	controlFrame.origin.y = containerFrame.size.height;
	
	if (animated) {
		[UIView animateWithDuration:0.2
						 animations:^{
							 container.frame = containerFrame;
							 controlView.frame = controlFrame;
						 }];
	}
	else {
		container.frame = containerFrame;
		controlView.frame = controlFrame;
	}
	
	[detailToggle setImage:[UIImage imageNamed:@"reveal.png"] forState:UIControlStateNormal];
}

- (void)voidButtonTapped:(id)sender
{
	INButton *button = (INButton *)sender;
	if ([button isKindOfClass:[INButton class]]) {
		showVoid = !showVoid;
		button.selected = showVoid;
		
		[self refreshListAnimated:YES];
	}
}



#pragma mark - Medication Actions
/**
 *	Reloads the current record's medications
 */
- (void)reloadList:(id)sender
{
	[medications removeAllObjects];
	[container showMeds:nil animated:NO];
	if (!record) {
		return;
	}
	
	// fetch this record's medications
	DLog(@"REFRESHING!");
	[record fetchAllReportsOfClass:[IndivoMedication class] callback:^(BOOL success, NSDictionary *userInfo) {
		
		// error fetching medications
		if (!success) {
			NSString *errorMessage = [[userInfo objectForKey:INErrorKey] localizedDescription];
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to get medications"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		
		// successfully fetched medications, display
		else {
			[medications setArray:[userInfo objectForKey:INResponseArrayKey]];
			[self processMedicationsAndRefresh:YES];
		}
	}];
}


- (void)refreshListAnimated:(BOOL)animated
{
	// filter meds
	NSPredicate *filter = [NSPredicate predicateWithBlock:^BOOL(IndivoMedication *aMed, NSDictionary *bindings) {
		if (!showVoid && (INDocumentStatusVoid == aMed.status)) {
			return NO;
		}
		if (minStopDate && aMed.prescription.stopOn) {
			return (minStopDate == [minStopDate earlierDate:[aMed.prescription.stopOn date]]);
		}
		return YES;
	}];
	NSArray *meds = [medications filteredArrayUsingPredicate:filter];
	
	// sort meds
	NSUInteger order = sortSelector.selectedSegmentIndex;
	meds = [meds sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		if (0 == order) {
			NSDate *date1 = [[[obj1 prescription] on] date];
			NSDate *date2 = [[[obj2 prescription] on] date];
			return [date1 compare:date2];
		}
		else if (1 == order) {
			NSDate *date1 = [[[obj1 prescription] stopOn] date];
			NSDate *date2 = [[[obj2 prescription] stopOn] date];
			if (!date1 && !date2) {				// order by start date if both have no stop date
				date1 = [[[obj1 prescription] on] date];
				date2 = [[[obj2 prescription] on] date];
			}
			if (!date1) {
				return NSOrderedDescending;		// those without stop date go to the end
			}
			return [date1 compare:date2];
		}
		return [[obj1 displayName] compare:[obj2 displayName]];
	}];
	
	// add meds to container
	[container showMeds:meds animated:animated];
}


/**
 *	Show the add-medication screen
 */
- (void)showNewMedView:(id)sender
{
	if (self.record) {
		UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissModalViewController:)];
		
		INNewMedViewController *newMed = [INNewMedViewController new];
		newMed.navigationItem.rightBarButtonItem = doneButton;
		newMed.delegate = self;
		
		UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:newMed];
		navi.navigationBar.tintColor = [APP_DELEGATE naviTintColor];
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



#pragma mark - Medication Processing
/**
 *	This methods walks through all IndivoMedication objects in self.medications and tries to group them
 */
- (void)processMedicationsAndRefresh:(BOOL)refresh
{
	if ([medications count] > 0) {
		[self indicateActivity:YES];
		
		INMedicationProcessor *proc = [INMedicationProcessor newWithMedications:medications];
		[proc processWithCallback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
			
			//--
			[medications removeAllObjects];
			for (IndivoMedicationGroup *group in proc.processedMedGroups) {
				IndivoMedication *med = [group.members firstObject];
				[medications addObjectIfNotNil:med];
			}
			//--
			
			if (refresh) {
				[self refreshListAnimated:NO];
			}
			[self indicateActivity:NO];
		}];
	}
}



#pragma mark - Indivo
/**
 *	Connecting to the server retrieves the records of your users account
 */
- (void)selectRecord:(id)sender
{
	[self indicateActivity:YES];
	
	// select record
	[APP_DELEGATE.indivo selectRecord:^(BOOL userDidCancel, NSString *errorMessage) {
		
		// there was an error selecting the record
		if (errorMessage) {
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
			[self reloadList:sender];
		}
		
		[self indicateActivity:NO];		// resets the activity spinner to the connect button
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
 *	We subscribe to notifications when the documents change with this method
 */
- (void)documentsDidChange:(NSNotification *)aNotification
{
//	IndivoRecord *aRecord = [[aNotification userInfo] objectForKey:INRecordUserInfoKey];
//	if ([aRecord isEqual:self.record]) {		// will always be true anyway...
//		[self reloadList:nil];
//	}
}



#pragma mark - IN(NewMed/EditMed)ViewControllerDelegate
- (void)newMedController:(INNewMedViewController *)theController didSelectMed:(IndivoMedication *)aMed;
{
	UINavigationController *naviController = (UINavigationController *)[self presentedViewController];
	if (![naviController isKindOfClass:[UINavigationController class]]) {
		DLog(@"PROBLEM! I'm not presenting a navigation controller while I should! Presenting: %@", naviController);
		return;
	}
	
	// put med into edit view
	INEditMedViewController *edit = [INEditMedViewController new];
	edit.med = aMed;
	edit.delegate = self;
	
	[naviController pushViewController:edit animated:YES];
}


- (void)editMedController:(INEditMedViewController *)theController didActOnMed:(IndivoMedication *)aMed
{
	[self dismissModalViewControllerAnimated:YES];
	if (![medications containsObject:aMed]) {			// this way we avoid one round-trip to the server
		[medications addObject:aMed];
	}
	[self refreshListAnimated:NO];
}

- (void)editMedController:(INEditMedViewController *)theController didReplaceMed:(IndivoMedication *)aMed withMed:(IndivoMedication *)newMed
{
	[self dismissModalViewControllerAnimated:YES];
	[self refreshListAnimated:NO];
}

- (void)editMedController:(INEditMedViewController *)theController didVoidMed:(IndivoMedication *)aMed
{
	[self dismissModalViewControllerAnimated:YES];
	[self refreshListAnimated:NO];
}

- (NSArray *)currentMedsForNewMedController:(INNewMedViewController *)theController
{
	return medications;
}



#pragma mark - UI Actions
/**
 *	Reverts the navigation bar "connect" button
 */
- (void)setRecordButtonTitle:(NSString *)aTitle
{
	NSString *title = ([aTitle length] > 0) ? aTitle : (([record.label length] > 0) ? record.label : @"Connect");
	UIBarButtonItem *connectButton = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleBordered target:self action:@selector(selectRecord:)];
	self.navigationItem.leftBarButtonItem = connectButton;
}

/**
 *	Dismiss current overlay view controller
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

/**
 *	Starts or stops the activity spinner
 */
- (void)indicateActivity:(BOOL)active
{
	if (active) {
		UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		UIBarButtonItem *activityButton = [[UIBarButtonItem alloc] initWithCustomView:activityView];
		[activityButton setTarget:self];
		[activityButton setAction:@selector(cancelSelection:)];
		
		self.navigationItem.leftBarButtonItem = activityButton;
		[activityView startAnimating];
	}
	else {
		[self setRecordButtonTitle:nil];
	}
}



#pragma mark - KVC
- (void)setRecord:(IndivoRecord *)aRecord
{
	if (aRecord != record) {
		record = aRecord;
	}
	
	[self setRecordButtonTitle:[record label]];
	sortSelector.enabled = (nil != record);
	self.navigationItem.titleView = (nil != record) ? sortSelector : nil;
	self.navigationItem.rightBarButtonItem.enabled = (nil != record);
	
	detailToggle.enabled = (nil != record);
	timeSlider.enabled = (nil != record);
	if (!record) {
		timeSliderInfo.text = nil;
		self.timeSliderFloater = nil;
		[self hideControlPaneAnimated:NO];
	}
}

/**
 *	The control view contains elements to control what is being shown
 */
- (UIView *)controlView
{
	if (!controlView) {
		CGSize mySize = [self.view bounds].size;
		CGFloat height = 50.f;
		CGRect aFrame = CGRectMake(0.f, mySize.height - height, mySize.width, height);
		self.controlView = [[UIView alloc] initWithFrame:aFrame];
		controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		controlView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"diagonal.png"]];
		
		// add the detail toggle
		CGRect toggleFrame = CGRectMake(15.f, 10.f, 40.f, 31.f);
		self.detailToggle = [[INButton alloc] initWithFrame:toggleFrame];
		[detailToggle addTarget:self action:@selector(toggleControlPane:) forControlEvents:UIControlEventTouchUpInside];
		[detailToggle setImage:[UIImage imageNamed:@"reveal.png"] forState:UIControlStateNormal];
		detailToggle.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
		detailToggle.enabled = (nil != record);
		[controlView addSubview:detailToggle];
		
		// add the time slider
		aFrame.origin = CGPointMake(toggleFrame.origin.x + toggleFrame.size.width + 15.f, 0.f);
		aFrame.size.width = mySize.width - aFrame.origin.x - 10.f;
		self.timeSlider = [[UISlider alloc] initWithFrame:aFrame];
		timeSlider.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
		timeSlider.value = 1.f;
		timeSlider.continuous = YES;
		timeSlider.enabled = (nil != record);
		[timeSlider addTarget:self action:@selector(timeSliderDidChange:) forControlEvents:UIControlEventValueChanged];
		[controlView addSubview:timeSlider];
		
		// add the void button
		CGRect voidFrame = CGRectMake(15.f, height + 5.f, 120.f, 31.f);
		INButton *showVoidButton =[[INButton alloc] initWithFrame:voidFrame];
		showVoidButton.tag = 2;
		showVoidButton.togglesState = YES;
		[showVoidButton setTitle:@"Show Void" forState:UIControlStateNormal];
		[showVoidButton addTarget:self action:@selector(voidButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		showVoidButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
		[controlView addSubview:showVoidButton];
		
		// the time info label
		voidFrame.origin.x += voidFrame.size.width + 8.f;
		voidFrame.size.width = mySize.width - voidFrame.origin.x - 15.f;
		self.timeSliderInfo = [[UILabel alloc] initWithFrame:voidFrame];
		timeSliderInfo.opaque = NO;
		timeSliderInfo.backgroundColor = [UIColor clearColor];
		timeSliderInfo.font = [UIFont systemFontOfSize:15.f];
		timeSliderInfo.textColor = [UIColor darkGrayColor];
		timeSliderInfo.textAlignment = UITextAlignmentRight;
		timeSliderInfo.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		timeSliderInfo.shadowOffset = CGSizeMake(0.f, 1.f);
		timeSliderInfo.text = @"Current";
		[controlView addSubview:timeSliderInfo];
		
		// add a shadow
		controlView.layer.shadowOpacity = 0.5f;
		controlView.layer.shadowRadius = 10.f;
	}
	return controlView;
}

- (UILabel *)timeSliderFloater
{
	if (!timeSliderFloater) {
		CGRect floatFrame = CGRectMake(0.f, 0.f, 160.f, 38.f);
		self.timeSliderFloater = [[UILabel alloc] initWithFrame:floatFrame];
		timeSliderFloater.opaque = NO;
		timeSliderFloater.clipsToBounds = NO;
		timeSliderFloater.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.8f];
		timeSliderFloater.font = [UIFont systemFontOfSize:17.f];
		timeSliderFloater.textColor = [UIColor whiteColor];
		timeSliderFloater.textAlignment = UITextAlignmentCenter;
		timeSliderFloater.layer.shadowOpacity = 0.5f;
		timeSliderFloater.layer.shadowRadius = 10.f;
		timeSliderFloater.layer.shadowOffset = CGSizeMake(0.f, 4.f);
		timeSliderFloater.layer.cornerRadius = 5.f;						// no effect???
	}
	return timeSliderFloater;
}


@end
