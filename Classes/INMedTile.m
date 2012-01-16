//
//  INMedTile.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedTile.h"
#import "INMedContainer.h"
#import "INMedDetailTile.h"
#import "IndivoMedication.h"
#import "INDateRangeFormatter.h"
#import "UIView+Utilities.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedTile ()

@property (nonatomic, strong) UIImageView *bgView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *statusView;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *nameLabel;

@property (nonatomic, strong) UIControl *dimView;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, strong) UIActivityIndicatorView *imageActivityView;
@property (nonatomic, assign) BOOL keepDimmedAfterAction;

@property (nonatomic, strong) INDateRangeFormatter *drFormatter;

- (void)updateDurationLabel;

@end


@implementation INMedTile

@synthesize med;
@synthesize container;
@synthesize bgView, imageView, statusView, durationLabel, nameLabel;
@synthesize dimView, activityView, imageActivityView, keepDimmedAfterAction;
@synthesize drFormatter, showsDetailTile;


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"white_carbon.png"]];
		self.clipsToBounds = YES;
		
		//UIImage *bgImage = [[UIImage imageNamed:@"tile.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(1.f, 1.f, 1.f, 1.f)];		// iOS 5+ only
		UIImage *bgImage = [[UIImage imageNamed:@"tile.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:1];
		self.bgView = [[UIImageView alloc] initWithImage:bgImage];
		self.bgView.frame = self.bounds;
		self.bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self addSubview:bgView];
		
		self.drFormatter = [INDateRangeFormatter new];
		[self addTarget:self action:@selector(showMedicationDetails:) forControlEvents:UIControlEventTouchUpInside];
	}
	return self;
}

+ (INMedTile *)tileWithMedication:(IndivoMedication *)aMed
{
	INMedTile *t = [[self alloc] initWithFrame:CGRectZero];
	t.med = aMed;
	return t;
}



#pragma mark - Layout
- (void)layoutSubviews
{
	CGRect bnds = [self bounds];
	CGSize size = bnds.size;
	
	bgView.frame = bnds;
	dimView.frame = bnds;
	
	CGFloat horiPad = 15.f;
	CGFloat vertPad = roundf(size.height / 10);
	
	// image
	CGFloat imgWidth = roundf(size.height / 2);
	CGRect imgFrame = CGRectMake(horiPad, vertPad, imgWidth, imgWidth);
	self.imageView.frame = imgFrame;
	
	// duration
	CGRect durFrame = self.durationLabel.frame;
	durFrame.origin.x = imgFrame.origin.x + imgFrame.size.width + roundf(horiPad / 2);
	durFrame.origin.y = imgFrame.origin.y;
	durFrame.size.width = size.width - durFrame.origin.x - horiPad;
	durationLabel.frame = durFrame;
	
	[self updateDurationLabel];
	
	/*
	CGRect statFrame = self.statusView.frame;
	statFrame.origin.x = size.width - horiPad - statFrame.size.width;
	statFrame.origin.y = imgFrame.origin.y + roundf((imgFrame.size.height - statFrame.size.height) / 2);
	self.statusView.frame = statFrame;	*/
	
	// name label
	CGRect lblFrame = CGRectMake(horiPad, 0.f, size.width - 2* horiPad, 21.f);
	lblFrame.origin.y = size.height - lblFrame.size.height - vertPad;
	self.nameLabel.frame = lblFrame;
}

- (void)updateDurationLabel
{
	drFormatter.from = med.prescription.on.date;
	drFormatter.to = med.prescription.stopOn.date;
	durationLabel.text = [drFormatter formattedRangeForLabel:durationLabel];
	
	/// @todo this should go to IndivoMedication
	NSDate *now = [NSDate date];
	UIColor *dateCol = [UIColor colorWithRed:0.f green:0.5f blue:0.f alpha:1.f];
	if (INDocumentStatusActive == med.status) {
		if (med.prescription.on.date == [med.prescription.on.date laterDate:now]) {
			dateCol = [UIColor colorWithRed:0.5f green:0.25f blue:0.f alpha:1.f];
		}
		else if (med.prescription.stopOn.date && med.prescription.stopOn.date == [med.prescription.stopOn.date earlierDate:now]) {
			dateCol = [UIColor colorWithRed:0.7f green:0.f blue:0.f alpha:1.f];
		}
	}
	else if (INDocumentStatusArchived == med.status) {
		dateCol = [UIColor colorWithRed:0.7f green:0.f blue:0.f alpha:1.f];
	}
	else if (INDocumentStatusVoid == med.status) {
		dateCol = [UIColor colorWithRed:0.7f green:0.f blue:0.f alpha:1.f];
		durationLabel.text = @"Voided";
	}
	durationLabel.textColor = dateCol;
}



#pragma mark - Dimming and Indicating Actions
/**
 *	Dims a tile
 */
- (void)dimAnimated:(BOOL)animated
{
	if (![activityView superview]) {
		keepDimmedAfterAction = YES;
		[self.dimView addTarget:self action:@selector(hideMedicationDetails:) forControlEvents:UIControlEventTouchUpInside];
	}
	if ([dimView superview]) {
		return;
	}
	[self addSubview:self.dimView];
	[self bringSubviewToFront:dimView];
	
	[UIView animateWithDuration:(animated ? 0.2 : 0.0)
					 animations:^{
						 dimView.layer.opacity = 1.f;
					 }];
}

/**
 *	Undims the tile
 */
- (void)undimAnimated:(BOOL)animated
{
	if (![activityView superview]) {
		[UIView animateWithDuration:(animated ? 0.2 : 0.0)
						 animations:^{
							 dimView.layer.opacity = 0.f;
						 }
						 completion:^(BOOL finished) {
							 [dimView removeFromSuperview];
							 self.dimView = nil;
						 }];
	}
	keepDimmedAfterAction = NO;
}


/**
 *	Shows or hides an acitivty indicator
 */
- (void)indicateAction:(BOOL)flag
{
	// show activity indicator
	if (flag) {
		[self.dimView addSubview:self.activityView];
		[activityView centerInSuperview];
		[activityView startAnimating];
		
		[self dimAnimated:YES];
	}
	
	// hide activity indicator
	else {
		[activityView stopAnimating];
		[activityView removeFromSuperview];
		self.activityView = nil;
		
		if (!keepDimmedAfterAction) {
			[self undimAnimated:YES];
		}
	}
}



#pragma mark - Detail Tile
/**
 *	Touching a tile will toggle the medication detail view
 */
- (void)showMedicationDetails:(id)sender
{
	if (showsDetailTile) {
		[self hideMedicationDetails:sender];
	}
	else {
		showsDetailTile = YES;
		
		INMedDetailTile *aDetailTile = [INMedDetailTile new];
		aDetailTile.med = self.med;
		[container addDetailTile:aDetailTile forTile:self animated:YES];
		[container dimAllBut:self];
	}
}

- (void)hideMedicationDetails:(id)sender
{
	[container removeDetailTileAnimated:YES];
	[container undimAll];
	showsDetailTile = NO;
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
- (void)setMed:(IndivoMedication *)newMed
{
	if (newMed != med) {
		med = newMed;
		
		self.nameLabel.text = [med displayName];
	}
}

- (UIImageView *)imageView
{
	if (!imageView) {
		self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pillDefault.png"]];
		imageView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		imageView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
		imageView.layer.cornerRadius = 6.f;
		imageView.layer.shadowColor = [[UIColor colorWithWhite:1.f alpha:0.8f] CGColor];
		imageView.layer.shadowRadius = 0.f;
		imageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
		imageView.layer.shadowOpacity = 1.f;
	//	imageView.clipsToBounds = YES;
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		imageView.backgroundColor = [UIColor blackColor];
		[self addSubview:imageView];
	}
	return imageView;
}

- (UIImageView *)statusView
{
	if (!statusView) {
		self.statusView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"statusGreen.png"]];
		statusView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
		//statusView.layer.shadowOpacity = 0.3f;
		//statusView.layer.shadowOffset = CGSizeMake(0.f, 2.f);
		//statusView.layer.shadowRadius = 3.f;
		[self addSubview:statusView];
	}
	return statusView;
}

- (UILabel *)nameLabel
{
	if (!nameLabel) {
		self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 10.f, 10.f)];
		nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		nameLabel.opaque = NO;
		nameLabel.backgroundColor = [UIColor clearColor];
		nameLabel.textColor = [UIColor blackColor];
		nameLabel.font = [UIFont systemFontOfSize:15.f];
		nameLabel.adjustsFontSizeToFitWidth = YES;
		nameLabel.minimumFontSize = 10.f;
		[self addSubview:nameLabel];
	}
	return nameLabel;
}

- (UILabel *)durationLabel
{
	if (!durationLabel) {
		self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 10.f, 19.f)];
		durationLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
		durationLabel.opaque = NO;
		durationLabel.backgroundColor = [UIColor clearColor];
		durationLabel.textColor = [UIColor blackColor];
		durationLabel.textAlignment = UITextAlignmentRight;
		durationLabel.font = [UIFont systemFontOfSize:15.f];
		durationLabel.adjustsFontSizeToFitWidth = YES;
		durationLabel.minimumFontSize = 10.f;
		[self addSubview:durationLabel];
	}
	return durationLabel;
}

- (UIControl *)dimView
{
	if (!dimView) {
		self.dimView = [[UIControl alloc] initWithFrame:self.bounds];
		dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		dimView.opaque = NO;
		dimView.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.75f];
		dimView.layer.opacity = 0.f;
	}
	return dimView;
}

- (UIActivityIndicatorView *)activityView
{
	if (!activityView) {
		self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		activityView.hidesWhenStopped = YES;
	}
	return activityView;
}

- (UIActivityIndicatorView *)imageActivityView
{
	if (!imageActivityView) {
		self.imageActivityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		imageActivityView.hidesWhenStopped = YES;
	}
	return imageActivityView;
}


@end
