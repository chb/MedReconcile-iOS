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
#import "IndivoMedication.h"
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
@property (nonatomic, strong) NSDate *minStopDate;
@property (nonatomic, strong) CAGradientLayer *controlTopShadow;

- (void)refreshListAnimated:(BOOL)animated;
- (void)showNewMedView:(id)sender;

- (void)sortSelectorDidChange:(id)sender;
- (void)timeSliderDidChange:(id)sender;
- (void)toggleControlPane:(id)sender;
- (void)showControlPaneAnimated:(BOOL)animated;
- (void)hideControlPaneAnimated:(BOOL)animated;
- (void)voidButtonTapped:(id)sender;

- (void)documentsDidChange:(NSNotification *)aNotification;
- (void)setRecordButtonTitle:(NSString *)aTitle;

@end


@implementation INMedListController

@synthesize record, medications;
@synthesize recordSelectButton, sortSelector;
@synthesize container, activeTile;
@synthesize showVoid;
@synthesize controlView, detailToggle, timeSlider, timeSliderInfo, minStopDate, controlTopShadow;


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
	
	if (1.f == timeSlider.value) {
		self.minStopDate = [NSDate date];
		timeSliderInfo.text = @"Current";
	}
	
	// we calculate the timepoint of "frac" between now and -10 years (age of patient would be desireable)
	else if (0.f != timeSlider.value) {
		CGFloat frac = powf(1.f - timeSlider.value, 3);
		NSDate *now = [NSDate date];
		self.minStopDate = [now dateByAddingTimeInterval:-frac * (10*365.25*24*3600)];
		
		NSDateFormatter *df = [[NSDateFormatter alloc] init];
		df.dateStyle = NSDateFormatterMediumStyle;
		df.timeStyle = NSDateFormatterNoStyle;
		timeSliderInfo.text = [df stringFromDate:minStopDate];
	}
	else {
		self.minStopDate = nil;
		timeSliderInfo.text = @"All";
	}
	[self refreshListAnimated:YES];
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
	
	// put the time label back
	CGRect infoFrame = [controlView viewWithTag:2].frame;
	infoFrame.origin.x += 8.f + infoFrame.size.width;
	infoFrame.size.width = mySize.width - 15.f - infoFrame.origin.x;
	
	if (animated) {
		[UIView animateWithDuration:0.2
						 animations:^{
							 container.frame = containerFrame;
							 controlView.frame = controlFrame;
							 timeSliderInfo.font = [UIFont systemFontOfSize:15.f];
							 timeSliderInfo.frame = infoFrame;
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
	
	// make the time label visible
	CGRect infoFrame = timeSliderInfo.frame;
	infoFrame.size.height = 14.f;
	infoFrame.origin.y = controlFrame.size.height - infoFrame.size.height;
	
	if (animated) {
		[UIView animateWithDuration:0.2
						 animations:^{
							 container.frame = containerFrame;
							 controlView.frame = controlFrame;
							 timeSliderInfo.font = [UIFont systemFontOfSize:12.f];
							 timeSliderInfo.frame = infoFrame;
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
	if (!record) {
		[medications removeAllObjects];
		[container showMeds:nil animated:NO];
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
			[self refreshListAnimated:NO];
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
		
		// cancelled
		else {
			self.record = nil;
		}
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
	IndivoRecord *aRecord = [[aNotification userInfo] objectForKey:INRecordUserInfoKey];
	if ([aRecord isEqual:self.record]) {		// will always be true anyway...
		[self reloadList:nil];
	}
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
	return;
	
	[aMed push:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (userDidCancel) {
			
		}
		else if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to add medication"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"Too Bad"
												  otherButtonTitles:nil];
			[alert show];
		}
		else {
			
			// successfully added medication
			[self dismissModalViewControllerAnimated:YES];
		}
	}];
}


- (void)editMedController:(INEditMedViewController *)theController didActOnMed:(IndivoMedication *)aMed
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)editMedController:(INEditMedViewController *)theController didReplaceMed:(IndivoMedication *)aMed withMed:(IndivoMedication *)newMed
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)editMedController:(INEditMedViewController *)theController didVoidMed:(IndivoMedication *)aMed
{
	[self dismissModalViewControllerAnimated:YES];
}



#pragma mark - UI Actions
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
- (void)dismissModalViewController:(id)sender
{
	if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {			// iOS 5+ only
		[self dismissViewControllerAnimated:YES completion:NULL];
	}
	else {
		[self dismissModalViewControllerAnimated:YES];
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
		CGFloat x = voidFrame.origin.x + voidFrame.size.width + 8.f;
		CGRect infoFrame = CGRectMake(x, height - 19.f, mySize.width - x - 15.f, 19.f);
		self.timeSliderInfo = [[UILabel alloc] initWithFrame:infoFrame];
		timeSliderInfo.opaque = NO;
		timeSliderInfo.backgroundColor = [UIColor clearColor];
		timeSliderInfo.font = [UIFont systemFontOfSize:12.f];
		timeSliderInfo.textColor = [UIColor darkGrayColor];
		timeSliderInfo.textAlignment = UITextAlignmentRight;
		timeSliderInfo.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		timeSliderInfo.shadowOffset = CGSizeMake(0.f, 1.f);
		timeSliderInfo.text = @"Current";
		[controlView addSubview:timeSliderInfo];
		
		// add the top shadow
		[controlView.layer addSublayer:self.controlTopShadow];
	}
	return controlView;
}

/**
 *	Returns the shadow attached to the top of the control view
 */
- (CAGradientLayer *)controlTopShadow
{
	if (!controlTopShadow) {
		self.controlTopShadow = [CAGradientLayer new];
		CGRect shadowFrame = CGRectMake(0.f, -22.f, [self.view bounds].size.width, 22.f);
		controlTopShadow.frame = shadowFrame;
		
		// create colors
		NSMutableArray *colors = [NSMutableArray arrayWithCapacity:6];
		CGFloat alphas[] = { 0.f, 0.0125f, 0.05f, 0.1125f, 0.2f, 0.3125f, 0.45f };
		for (NSUInteger i = 0; i < 7; i++) {
			CGColorRef color = CGColorRetain([[UIColor colorWithWhite:0.f alpha:alphas[i]] CGColor]);
			[colors addObject:(__bridge_transfer id)color];
		}
		controlTopShadow.colors = colors;
		
		// prevent frame animation
		//bottomShadow.actions = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"position"];
	}
	return controlTopShadow;
}


@end
