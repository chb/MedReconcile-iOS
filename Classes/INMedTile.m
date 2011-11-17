//
//  INMedTile.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedTile.h"
#import <QuartzCore/QuartzCore.h>
#import "IndivoMedication.h"


@interface INMedTile ()

@property (nonatomic, strong) UIImageView *bgView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *statusView;
@property (nonatomic, strong) UILabel *nameLabel;

@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, assign) BOOL keepDimmedAfterAction;

@end


@implementation INMedTile

@synthesize med;
@synthesize container;
@synthesize bgView, imageView, statusView, nameLabel;
@synthesize dimView, activityView, keepDimmedAfterAction;


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.backgroundColor = [UIColor whiteColor];
		self.layer.shadowColor = [[UIColor colorWithWhite:0.f alpha:0.5f] CGColor];
		self.layer.shadowOffset = CGSizeMake(0.f, 1.f);
		self.layer.shadowRadius = 4.f;
		
		//UIImage *bgImage = [[UIImage imageNamed:@"tile.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0.f, 0.f, 1.f, 1.f)];		// iOS 5+ only
		UIImage *bgImage = [[UIImage imageNamed:@"tile.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:1];
		self.bgView = [[UIImageView alloc] initWithImage:bgImage];
		self.bgView.frame = self.bounds;
		self.bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self addSubview:bgView];
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
	
	// image
	CGFloat horiPad = 15.f;
	CGFloat vertPad = roundf(size.height / 10);
	CGFloat imgWidth = roundf(size.height / 2);
	CGRect imgFrame = CGRectMake(horiPad, vertPad, imgWidth, imgWidth);
	self.imageView.frame = imgFrame;
	
	// name label
	CGRect lblFrame = CGRectMake(horiPad, 0.f, size.width - 2* horiPad, 21.f);
	lblFrame.origin.y = size.height - lblFrame.size.height - vertPad;
	self.nameLabel.frame = lblFrame;
}



#pragma mark - Action Handling
/**
 *	Dims or undims a tile
 */
- (void)dim:(BOOL)flag
{
	if (flag) {
		[self dimAnimated:YES];
	}
	else {
		[self undimAnimated:YES];
	}
}

- (void)dimAnimated:(BOOL)animated
{
	if (![activityView superview]) {
		keepDimmedAfterAction = YES;
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
		CGSize dimSize = [dimView bounds].size;
		CGRect actFrame = activityView.frame;
		actFrame.origin.x = roundf((dimSize.width - actFrame.size.width) / 2);
		actFrame.origin.y = roundf((dimSize.height - actFrame.size.height) / 2);
		activityView.frame = actFrame;
		[activityView startAnimating];
		
		[self dimAnimated:YES];
	}
	
	// hide activity indicator
	else if (!keepDimmedAfterAction) {
		[activityView stopAnimating];
		[activityView removeFromSuperview];
		self.activityView = nil;
		
		[self undimAnimated:YES];
	}
}

/**
 *	Touching a tile should toggle the medication detail view
 */
- (void)showMedicationDetails:(id)sender
{
	
}

- (void)hideMedicationDetails:(id)sender
{
	
}



#pragma mark - KVC
- (void)setMed:(IndivoMedication *)newMed
{
	if (newMed != med) {
		med = newMed;
		
		self.nameLabel.text = med.name.text;
	}
}

- (UIImageView *)imageView
{
	if (!imageView) {
		self.imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pillDefault"]];
		[self addSubview:imageView];
	}
	return imageView;
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

- (UIView *)dimView
{
	if (!dimView) {
		self.dimView = [[UIView alloc] initWithFrame:self.bounds];
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


@end
