//
//  INMedDetailTile.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedDetailTile.h"
#import "IndivoMedication.h"
#import "INMedEditViewController.h"
#import "INMedTile.h"
#import "INMedContainer.h"
#import "INDateRangeFormatter.h"
#import "UIView+Utilities.h"
#import "INButton.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedDetailTile ()

@property (nonatomic, strong) INDateRangeFormatter *drFormatter;
@property (nonatomic, strong) UIActivityIndicatorView *imageActivityView;

@property (nonatomic, strong) CAGradientLayer *topShadow;
@property (nonatomic, strong) CAGradientLayer *bottomShadow;

- (void)setup;

@end


@implementation INMedDetailTile

@synthesize med, forTile, drFormatter;
@synthesize imageView, agentName, rxNormButton, versionsButton;
@synthesize prescName, prescDuration, prescInstructions, prescDoctor, prescMainButton, prescChangeButton;
@synthesize imageActivityView;
@synthesize topShadow, bottomShadow;


+ (id)new
{
	NSArray *parts = [[NSBundle mainBundle] loadNibNamed:@"INMedDetailTile" owner:nil options:nil];
	if ([parts count] < 1) {
		DLog(@"Failed to load INMedDetailTile XIB");
		return nil;
	}
	INMedDetailTile *t = [parts objectAtIndex:0];
	[t setup];
	
	return t;
}

- (id)initWithFrame:(CGRect)frame
{
	INMedDetailTile *t = [[self class] new];
	t.frame = frame;
	/// @todo how does this play with ARC??
	return t;
}

- (void)setup
{
	self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"diagonal.png"]];
	self.clipsToBounds = YES;
	
	// setup buttons
	prescMainButton.buttonStyle = INButtonStyleDestructive;
	prescChangeButton.buttonStyle = INButtonStyleMain;
	
	// tune imageView
	imageView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
	imageView.layer.cornerRadius = 6.f;
	imageView.layer.shadowColor = [[UIColor colorWithWhite:1.f alpha:0.8f] CGColor];
	imageView.layer.shadowRadius = 0.f;
	imageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
	imageView.layer.shadowOpacity = 1.f;
	imageView.contentMode = UIViewContentModeScaleAspectFit;
	imageView.backgroundColor = [UIColor blackColor];
	
	// add shadows
	[self.layer addSublayer:self.topShadow];
	[self.layer addSublayer:self.bottomShadow];
}



#pragma mark - Layout
- (void)layoutSubviews
{
	[super layoutSubviews];
	
	prescDuration.text = [drFormatter formattedRangeForLabel:prescDuration];
	/// @todo update instructions size
}

- (void)pointAtX:(CGFloat)x
{
	CGSize mySize = [self bounds].size;
	x = (x >= 10.f) ? x : 10.f;
	
	/* create the mask
	CAShapeLayer *mask = (CAShapeLayer *)self.topShadow.mask;
	if (![mask isKindOfClass:[CAShapeLayer class]]) {
		mask = [CAShapeLayer new];
	}
	
	BOOL add = (nil != [topShadow superlayer]);
	[topShadow removeFromSuperlayer];
	
	// create the path
	CGMutablePathRef path = CGPathCreateMutable();
	
	CGPathMoveToPoint(path, NULL, 0.f, 12.f);
	CGPathAddLineToPoint(path, NULL, x - 10.f, 12.f);
	CGPathAddLineToPoint(path, NULL, x, 2.f);
	CGPathAddLineToPoint(path, NULL, x + 10.f, 12.f);
	CGPathAddLineToPoint(path, NULL, mySize.width, 12.f);
	CGPathAddLineToPoint(path, NULL, mySize.width, 40.f);
	CGPathAddLineToPoint(path, NULL, 0.f, 40.f);
	CGPathCloseSubpath(path);
	mask.path = path;
	CGPathRelease(path);
	
	topShadow.mask = mask;
	if (add) {
		[self.layer addSublayer:topShadow];
	}	//	*/
	
	// create the color layer
	[[topShadow sublayers] makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
	CAShapeLayer *shape = [CAShapeLayer new];
	shape.fillColor = [[UIColor colorWithWhite:1.f alpha:0.8f] CGColor];
	shape.strokeColor = [[UIColor whiteColor] CGColor];
	shape.lineWidth = 1.f;
	
	CGMutablePathRef path = CGPathCreateMutable();
	
	CGPathMoveToPoint(path, NULL, -0.5f, 0.5f);
	CGPathAddLineToPoint(path, NULL, mySize.width + 1.f, 0.5f);
	CGPathAddLineToPoint(path, NULL, mySize.width + 1.f, 12.5f);
	CGPathAddLineToPoint(path, NULL, x + 10.f, 12.5f);
	CGPathAddLineToPoint(path, NULL, x, 2.5f);
	CGPathAddLineToPoint(path, NULL, x - 10.f, 12.5f);
	CGPathAddLineToPoint(path, NULL, -0.5f, 12.5f);
	CGPathCloseSubpath(path);
	
	shape.path = path;
	CGPathRelease(path);
	[topShadow addSublayer:shape];
}



#pragma mark - Actions
- (void)showRxNormBrowser:(id)sender
{
	
}

- (void)showVersions:(id)sender
{
	
}

- (void)triggerMainAction:(id)sender
{
	INButton *theButton = [sender isKindOfClass:[INButton class]] ? (INButton *)sender : nil;
	[theButton indicateAction:YES];
	[med setLabel:@"TEST" callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Action failed"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}
		[theButton indicateAction:NO];
	}];
}

/**
 *	Instantiates and presents an INMedEditViewController modally
 */
- (void)editMed:(id)sender
{
	INMedEditViewController *editController = [INMedEditViewController new];
	if (editController) {
		editController.med = self.med;
		UINavigationController *tempNavi = [[UINavigationController alloc] initWithRootViewController:editController];
		
		// add cancel and save buttons
		UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:tempNavi action:@selector(dismiss:)];
		editController.navigationItem.leftBarButtonItem = cancelButton;
		
		UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:editController action:@selector(saveMed:)];
		editController.navigationItem.rightBarButtonItem = saveButton;
		
		// find the parent
		UIViewController *parent = self.forTile.container.viewController;
		if (parent.navigationController) {
			parent = parent.navigationController;
		}
		
		// present
		if (parent) {
			if ([parent respondsToSelector:@selector(presentViewController:animated:completion:)]) {		/// iOS 5.0+ only
				[parent presentViewController:tempNavi animated:YES completion:NULL];
			}
			else {
				[parent presentModalViewController:tempNavi animated:YES];
			}
		}
		else {
			DLog(@"Failed to find the view controller along the chain:\ntile: %@\ncontainer: %@\ncontroller: %@", self.forTile, self.forTile.container, self.forTile.container.viewController);
		}
	}
	else {
		DLog(@"Failed to instantiate an INMedEditViewController!");
	}
}



#pragma mark - Image Handling
/**
 *	Starts or stops the activity indicator on the image view
 */
- (void)indicateImageAction:(BOOL)flag
{
	if (flag) {
		[imageView addSubview:self.imageActivityView];
		[imageActivityView centerInSuperview];
		[imageActivityView startAnimating];
	}
	else {
		[imageActivityView stopAnimating];
		[imageActivityView removeFromSuperview];
		self.imageActivityView = nil;
	}
}

/**
 *	Displays the given image instead of the default image
 */
- (void)showImage:(UIImage *)anImage
{
	imageView.image = anImage ? anImage : [UIImage imageNamed:@"pillDefault.png"];
}



#pragma mark - KVC
- (void)setMed:(IndivoMedication *)aMed
{
	if (aMed != med) {
		med = aMed;
		
		// name and info
		agentName.text = med.name.abbrev ? med.name.abbrev : med.name.text;
		prescName.text = med.brandName.abbrev ? med.brandName.abbrev : med.brandName.text;
		
		// date
		self.drFormatter.from = med.prescription.on.date;
		self.drFormatter.to = med.prescription.stopOn.date;
		
		// image
		if (med.pillImage) {
			imageView.image = med.pillImage;
		}
		else {
			[self indicateImageAction:YES];
			[med loadPillImageBypassingCache:NO callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
				[self showImage:med.pillImage];
				[self indicateImageAction:NO];
			}];
		}
	}
}

- (INDateRangeFormatter *)drFormatter
{
	if (!drFormatter) {
		self.drFormatter = [INDateRangeFormatter new];
	}
	return drFormatter;
}

- (UIActivityIndicatorView *)imageActivityView
{
	if (!imageActivityView) {
		self.imageActivityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		imageActivityView.hidesWhenStopped = YES;
	}
	return imageActivityView;
}

/**
 *	Returns the top shadow layer
 */
- (CAGradientLayer *)topShadow
{
	if (!topShadow) {
		CGSize mySize = [self bounds].size;
		
		self.topShadow = [CAGradientLayer new];
		topShadow.bounds = CGRectMake(0.f, 0.f, mySize.width, 40.f);
		topShadow.anchorPoint = CGPointMake(0.f, 0.f);
		topShadow.position = CGPointZero;
		
		// create colors
		NSMutableArray *colors = [NSMutableArray arrayWithCapacity:6];
		NSMutableArray *locations = [NSMutableArray arrayWithCapacity:6];
		CGFloat alphas[] = { 0.45f, 0.3125f, 0.2f, 0.1125f, 0.05f, 0.0125f, 0.f };		// y = 0.45 x^2
		CGFloat locs[] = { 0.25f, 0.375f, 0.5f, 0.625f, 0.75f, 0.875f, 1.f };
		for (NSInteger i = 0; i < 7; i++) {
			CGColorRef color = CGColorRetain([[UIColor colorWithWhite:0.f alpha:alphas[i]] CGColor]);
			[colors addObject:(__bridge_transfer id)color];
			[locations addObject:[NSNumber numberWithFloat:locs[i]]];
		}
		topShadow.colors = colors;
		topShadow.locations = locations;
	}
	return topShadow;
}

/**
 *	Returns the bottom shadow layer
 */
- (CAGradientLayer *)bottomShadow
{
	if (!bottomShadow) {
		self.bottomShadow = [CAGradientLayer new];
		CGRect shadowFrame = CGRectMake(0.f, 0.f, [self bounds].size.width, 22.f);
		bottomShadow.bounds = shadowFrame;
		bottomShadow.anchorPoint = CGPointMake(0.f, 1.f);
		bottomShadow.position = CGPointMake(0.f, [self bounds].size.height);
		
		// create colors
		NSMutableArray *colors = [NSMutableArray arrayWithCapacity:6];
		NSMutableArray *locations = [NSMutableArray arrayWithCapacity:6];
		CGFloat alphas[] = { 0.f, 0.0125f, 0.05f, 0.1125f, 0.2f, 0.3125f, 0.6f };
		CGFloat locs[] = { 0.f, 0.2f, 0.4f, 0.6f, 0.8f, 0.954f, 0.954f };			// last value constitutes 1 pixel (1 - 1/22)
		for (NSInteger i = 0; i < 7; i++) {
			CGColorRef color = CGColorRetain([[UIColor colorWithWhite:(i < 6 ? 0.f : 1.f) alpha:alphas[i]] CGColor]);
			[colors addObject:(__bridge_transfer id)color];
			[locations addObject:[NSNumber numberWithFloat:locs[i]]];
		}
		bottomShadow.colors = colors;
		bottomShadow.locations = locations;
	}
	return bottomShadow;
}


@end
