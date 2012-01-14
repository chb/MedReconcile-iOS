//
//  INButton.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/14/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INButton.h"
#import "UIView+Utilities.h"
#import <QuartzCore/QuartzCore.h>


@interface INButton()

@property (nonatomic, strong) UIActivityIndicatorView *activity;
@property (nonatomic, copy) NSString *originalTitle;
@property (nonatomic, assign) UIEdgeInsets originalInsets;

@end


@implementation INButton

@synthesize buttonStyle, object;
@synthesize activity, originalTitle, originalInsets;


- (void)setup
{
	self.contentEdgeInsets = UIEdgeInsetsMake(2.f, 8.f, 2.f, 8.f);
	
	UIImage *grayButtonImage = [[UIImage imageNamed:@"buttonGray.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
	UIImage *disabledButtonImage = [[UIImage imageNamed:@"buttonDisabled.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
	UIImage *pressedButtonImage = [[UIImage imageNamed:@"buttonPressed.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
	self.buttonStyle = INButtonStyleStandard;
	
	[self setBackgroundImage:grayButtonImage forState:UIControlStateNormal];
	[self setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[self setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	
	self.layer.shadowOffset = CGSizeMake(0.f, 1.f);
	self.layer.shadowOpacity = 0.4f;
	self.layer.shadowRadius = 2.f;
}

- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		[self setup];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder])) {
		[self setup];
	}
	return self;
}

+ (id)buttonWithStyle:(INButtonStyle)aStyle
{
	INButton *b = [self new];
	[b setup];
	b.buttonStyle = aStyle;
	return b;
}



#pragma mark - Action Indication
/**
 *	Start or stops an activity indicator view on the button
 *	@param action Whether or not to show the indicator
 */
- (void)indicateAction:(BOOL)action
{
	// show action
	if (action) {
		if (self != [activity superview]) {
			self.originalInsets = self.contentEdgeInsets;
			CGSize mySize = [self bounds].size;
			
			// create the spinner
			self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:(INButtonStyleStandard == buttonStyle ? UIActivityIndicatorViewStyleGray : UIActivityIndicatorViewStyleWhite)];
			activity.userInteractionEnabled = NO;
			activity.exclusiveTouch = NO;
			CGFloat leftPadding = 6.f;
			CGRect actFrame = activity.frame;
			
			// do we have enough room?
			CGSize need = [self.titleLabel.text sizeWithFont:self.titleLabel.font];
			BOOL center = (need.width > mySize.width - (actFrame.size.width + leftPadding + originalInsets.left + originalInsets.right));
			
			if (!center) {
				activity.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
				actFrame.origin.x = leftPadding;
				actFrame.origin.y = roundf((mySize.height - actFrame.size.height) / 2);
				activity.frame = actFrame;
				self.contentEdgeInsets = UIEdgeInsetsMake(0.f, actFrame.origin.x + actFrame.size.width, 0.f, 0.f);
			}
			
			// add and start
			[self addSubview:activity];
			[activity startAnimating];
			if (center) {
				self.originalTitle = [self titleForState:UIControlStateNormal];
				[self setTitle:nil forState:UIControlStateNormal];
				[activity centerInSuperview];
			}
		}
	}
	
	// stop showing
	else {
		if (originalTitle) {
			[self setTitle:originalTitle forState:UIControlStateNormal];
			self.originalTitle = nil;
		}
		[activity stopAnimating];
		[activity removeFromSuperview];
		self.contentEdgeInsets = self.originalInsets;
	}
}



#pragma mark - KVC and Overrides
- (void)setButtonStyle:(INButtonStyle)newStyle
{
	if (newStyle != buttonStyle) {
		buttonStyle = newStyle;
		
		// update look
		UIImage *bgImage = nil;
		UIColor *shadowColor = nil;
		UIColor *textColor = nil;
		CGSize shadowOffset = CGSizeZero;
		
		if (INButtonStyleDestructive == buttonStyle) {
			bgImage = [[UIImage imageNamed:@"buttonRed.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];		///< @todo Update to newer method once iOS < 5 is dropped
			shadowColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			textColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0.f, -1.f);
		}
		else if (INButtonStyleAccept == buttonStyle) {
			bgImage = [[UIImage imageNamed:@"buttonGreen.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
			shadowColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			textColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0.f, -1.f);
		}
		else if (INButtonStyleMain == buttonStyle) {
			bgImage = [[UIImage imageNamed:@"buttonBlue.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
			shadowColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			textColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0.f, -1.f);
		}
		else {
			bgImage = [[UIImage imageNamed:@"buttonGray.png"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
			shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
			textColor = [UIColor darkGrayColor];
			shadowOffset = CGSizeMake(0.f, 1.f);
		}
		
		[self setBackgroundImage:bgImage forState:UIControlStateNormal];
		[self setTitleColor:textColor forState:UIControlStateNormal];
		[self setTitleShadowColor:shadowColor forState:UIControlStateNormal];
		self.titleLabel.shadowOffset = shadowOffset;
	}
}


@end
