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
#import "IndivoDocuments.h"
#import "INDateRangeFormatter.h"
#import "UIView+Utilities.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedTile ()

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


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.clipsToBounds = YES;
		self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"diagonal.png"]];
		
		//UIImage *bgImage = [[UIImage imageNamed:@"tile.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(1.f, 1.f, 1.f, 1.f)];		// iOS 5+ only
		UIImage *bgImage = [[UIImage imageNamed:@"tile.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:1];
		UIView *bgView = [[UIImageView alloc] initWithImage:bgImage];
		bgView.tag = 1;
		bgView.frame = self.bounds;
		bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
	
	[self viewWithTag:1].frame = bnds;
	_dimView.frame = bnds;
	
	CGFloat horiPad = 15.f;
	CGFloat vertPad = roundf(size.height / 10);
	
	// name
	CGRect lblFrame = self.nameLabel.frame;
	lblFrame.origin = CGPointMake(horiPad, vertPad);
	lblFrame.size.width = size.width - 2*horiPad;
	_nameLabel.frame = lblFrame;
	
	// time and status
	CGRect durFrame = self.durationLabel.frame;
	CGRect statFrame = self.statusView.frame;
	durFrame.origin = CGPointMake(horiPad, lblFrame.origin.y + lblFrame.size.height + 4.f);
	durFrame.size.width = size.width - horiPad - horiPad - statFrame.size.width - 8.f;
	_durationLabel.frame = durFrame;
	[self updateDurationLabel];
	
	statFrame.origin.x = durFrame.origin.x + durFrame.size.width + 8.f;
	statFrame.origin.y = durFrame.origin.y + roundf((durFrame.size.height - statFrame.size.height) / 2);
	_statusView.frame = statFrame;
}

- (void)setFrame:(CGRect)aFrame
{
	[super setFrame:aFrame];
	_shadow.frame = aFrame;
}

- (void)updateDurationLabel
{
	_drFormatter.from = _med.startDate.date;
	_drFormatter.to = _med.endDate.date;
	_durationLabel.text = [_drFormatter formattedRangeForLabel:_durationLabel];
	
	/// @todo this should go to IndivoMedication
	NSDate *now = [NSDate date];
	UIColor *dateCol = [UIColor colorWithRed:0.f green:0.5f blue:0.f alpha:1.f];
	if (INDocumentStatusActive == _med.documentStatus) {
		if (_med.startDate.date == [_med.startDate.date laterDate:now]) {
			dateCol = [UIColor colorWithRed:0.5f green:0.25f blue:0.f alpha:1.f];
		}
		else if (_med.endDate.date && _med.endDate.date == [_med.endDate.date earlierDate:now]) {
			dateCol = [UIColor colorWithRed:0.7f green:0.f blue:0.f alpha:1.f];
		}
	}
	else if (INDocumentStatusArchived == _med.documentStatus) {
		dateCol = [UIColor colorWithRed:0.7f green:0.f blue:0.f alpha:1.f];
	}
	else if (INDocumentStatusVoid == _med.documentStatus) {
		dateCol = [UIColor colorWithRed:0.7f green:0.f blue:0.f alpha:1.f];
		_durationLabel.text = @"Voided";
	}
	_durationLabel.textColor = dateCol;
}



#pragma mark - View Hierarchy
- (void)removeAnimated:(BOOL)animated
{
	if (66 == self.tag) {
		return;
	}
	
	if (animated) {
		self.tag = 66;
		[UIView animateWithDuration:kINMedContainerAnimDuration
						 animations:^{
							 self.layer.opacity = _shadow.layer.opacity = 0.5f;
							 self.transform = _shadow.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
						 }
						 completion:^(BOOL finished) {
							 [self removeFromSuperview];
							 [_shadow removeFromSuperview];
						 }];
	}
	else {
		[self removeFromSuperview];
		[_shadow removeFromSuperview];
	}
}



#pragma mark - Dimming and Indicating Actions
/**
 *  Dims a tile
 */
- (void)dimAnimated:(BOOL)animated
{
	if (![_activityView superview]) {
		_keepDimmedAfterAction = YES;
		[self.dimView addTarget:self action:@selector(hideMedicationDetails:) forControlEvents:UIControlEventTouchUpInside];
	}
	if ([_dimView superview]) {
		return;
	}
	[self addSubview:self.dimView];
	[self bringSubviewToFront:_dimView];
	
	[UIView animateWithDuration:(animated ? 0.2 : 0.0)
					 animations:^{
						 _dimView.layer.opacity = 1.f;
					 }];
}

/**
 *  Undims the tile
 */
- (void)undimAnimated:(BOOL)animated
{
	if (![_activityView superview]) {
		[UIView animateWithDuration:(animated ? 0.2 : 0.0)
						 animations:^{
							 _dimView.layer.opacity = 0.f;
						 }
						 completion:^(BOOL finished) {
							 [_dimView removeFromSuperview];
							 self.dimView = nil;
						 }];
	}
	_keepDimmedAfterAction = NO;
}


/**
 *  Shows or hides an acitivty indicator
 */
- (void)indicateAction:(BOOL)flag
{
	// show activity indicator
	if (flag) {
		[self.dimView addSubview:self.activityView];
		[_activityView centerInSuperview];
		[_activityView startAnimating];
		
		[self dimAnimated:YES];
	}
	
	// hide activity indicator
	else {
		[_activityView stopAnimating];
		[_activityView removeFromSuperview];
		self.activityView = nil;
		
		if (!_keepDimmedAfterAction) {
			[self undimAnimated:YES];
		}
	}
}



#pragma mark - Detail Tile
/**
 *  Touching a tile will toggle the medication detail view
 */
- (void)showMedicationDetails:(id)sender
{
	if (_showsDetailTile) {
		[self hideMedicationDetails:sender];
	}
	else {
		_showsDetailTile = YES;
		
		INMedDetailTile *aDetailTile = [INMedDetailTile new];
		aDetailTile.med = self.med;
		[_container addDetailTile:aDetailTile forTile:self animated:YES];
	}
}

- (void)hideMedicationDetails:(id)sender
{
	[_container removeDetailTileAnimated:YES];
	_showsDetailTile = NO;
}



#pragma mark - Image Handling
/**
 *  Starts or stops the activity indicator on the image view
 */
- (void)indicateImageAction:(BOOL)flag
{
	if (flag) {
		[_imageView addSubview:self.imageActivityView];
		[_imageActivityView centerInSuperview];
		[_imageActivityView startAnimating];
	}
	else {
		[_imageActivityView stopAnimating];
		[_imageActivityView removeFromSuperview];
		self.imageActivityView = nil;
	}
}

/**
 *  Displays the given image instead of the default image
 */
- (void)showImage:(UIImage *)anImage
{
	_imageView.image = anImage ? anImage : [UIImage imageNamed:@"pillDefault.png"];
}



#pragma mark - KVC
- (void)setMed:(IndivoMedication *)newMed
{
	if (newMed != _med) {
		_med = newMed;
		
		self.nameLabel.text = [_med displayName];
	}
}

- (UIImageView *)imageView
{
	if (!_imageView) {
		self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pillDefault.png"]];
		_imageView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		_imageView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
		_imageView.layer.cornerRadius = 6.f;
		_imageView.layer.shadowColor = [[UIColor colorWithWhite:1.f alpha:0.8f] CGColor];
		_imageView.layer.shadowRadius = 0.f;
		_imageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
		_imageView.layer.shadowOpacity = 1.f;
	//	_imageView = YES;
		_imageView.contentMode = UIViewContentModeScaleAspectFit;
		_imageView.backgroundColor = [UIColor blackColor];
		[self addSubview:_imageView];
	}
	return _imageView;
}

- (UIImageView *)statusView
{
	if (!_statusView) {
		self.statusView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"statusGreen.png"]];
		_statusView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
		//_statusView.layer.shadowOpacity = 0.3f;
		//_statusView.layer.shadowOffset = CGSizeMake(0.f, 2.f);
		//_statusView.layer.shadowRadius = 3.f;
		[self addSubview:_statusView];
	}
	return _statusView;
}

- (UILabel *)nameLabel
{
	if (!_nameLabel) {
		self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 130.f, 24.f)];
		_nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
		_nameLabel.opaque = NO;
		_nameLabel.backgroundColor = [UIColor clearColor];
		_nameLabel.textColor = [UIColor blackColor];
		_nameLabel.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		_nameLabel.shadowOffset = CGSizeMake(0.f, 1.f);
		_nameLabel.font = [UIFont boldSystemFontOfSize:19.f];
		_nameLabel.adjustsFontSizeToFitWidth = YES;
		_nameLabel.minimumFontSize = 10.f;
		[self addSubview:_nameLabel];
	}
	return _nameLabel;
}

- (UILabel *)durationLabel
{
	if (!_durationLabel) {
		self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 90.f, 19.f)];
		_durationLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
		_durationLabel.opaque = NO;
		_durationLabel.backgroundColor = [UIColor clearColor];
		_durationLabel.textColor = [UIColor blackColor];
		_durationLabel.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		_durationLabel.shadowOffset = CGSizeMake(0.f, 1.f);
		_durationLabel.textAlignment = UITextAlignmentLeft;
		_durationLabel.font = [UIFont systemFontOfSize:15.f];
		_durationLabel.adjustsFontSizeToFitWidth = YES;
		_durationLabel.minimumFontSize = 10.f;
		[self addSubview:_durationLabel];
	}
	return _durationLabel;
}

- (UIControl *)dimView
{
	if (!_dimView) {
		self.dimView = [[UIControl alloc] initWithFrame:self.bounds];
		_dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_dimView.opaque = NO;
		_dimView.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.75f];
		_dimView.layer.opacity = 0.f;
	}
	return _dimView;
}

- (UIActivityIndicatorView *)activityView
{
	if (!_activityView) {
		self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		_activityView.hidesWhenStopped = YES;
	}
	return _activityView;
}

- (UIActivityIndicatorView *)imageActivityView
{
	if (!_imageActivityView) {
		self.imageActivityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		_imageActivityView.hidesWhenStopped = YES;
	}
	return _imageActivityView;
}

- (UIView *)shadow
{
	// TODO: figure out why the transform is not being applied, then re-enable
	return nil;
	if (!_shadow) {
		self.shadow = [[UIView alloc] initWithFrame:self.frame];
		UIColor *back = [[self viewWithTag:1] backgroundColor];
		back = back ? back : [UIColor whiteColor];
		_shadow.backgroundColor = back;
		_shadow.layer.shadowOffset = CGSizeMake(0.f, 4.f);
		_shadow.layer.shadowOpacity = 0.5f;
		_shadow.layer.shadowRadius = 10.f;
	}
	return _shadow;
}


@end
