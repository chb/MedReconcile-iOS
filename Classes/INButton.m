//
//  INButton.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/14/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INButton.h"

@implementation INButton

@synthesize buttonStyle;

- (void)setup
{
	UIImage *grayButtonImage = [[UIImage imageNamed:@"buttonGray.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *disabledButtonImage = [[UIImage imageNamed:@"buttonDisabled.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *pressedButtonImage = [[UIImage imageNamed:@"buttonPressed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	self.buttonStyle = INButtonStyleStandard;
	
	[self setBackgroundImage:grayButtonImage forState:UIControlStateNormal];
	[self setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[self setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
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
	b.buttonStyle = aStyle;
	return b;
}



#pragma mark - Button Style
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
			bgImage = [[UIImage imageNamed:@"buttonRed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];		///< @todo Update to newer method once iOS < 5 is dropped
			shadowColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			textColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0.f, -1.f);
		}
		else if (INButtonStyleAccept == buttonStyle) {
			bgImage = [[UIImage imageNamed:@"buttonGreen.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
			shadowColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			textColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0.f, -1.f);
		}
		else if (INButtonStyleMain == buttonStyle) {
			bgImage = [[UIImage imageNamed:@"buttonBlue.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
			shadowColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			textColor = [UIColor whiteColor];
			shadowOffset = CGSizeMake(0.f, -1.f);
		}
		else {
			bgImage = [[UIImage imageNamed:@"buttonGray.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
			shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
			textColor = [UIColor darkGrayColor];
			shadowOffset = CGSizeMake(0.f, 1.f);
		}
		
		[self setBackgroundImage:bgImage forState:UIControlStateNormal];
		self.titleLabel.shadowColor = shadowColor;
		self.titleLabel.textColor = textColor;
		self.titleLabel.shadowOffset = shadowOffset;
	}
}


@end
