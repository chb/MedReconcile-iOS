//
//  INMedDetailTile.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedDetailTile.h"
#import "IndivoMedication.h"
#import "INDateRangeFormatter.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedDetailTile ()

@property (nonatomic, strong) INDateRangeFormatter *drFormatter;

- (void)setup;

@end


@implementation INMedDetailTile

@synthesize med, forTile, drFormatter;
@synthesize imageView, agentName, rxNormButton, versionsButton;
@synthesize prescName, prescDuration, prescInstructions, prescDoctor, prescMainButton, prescChangeButton;


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
	self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"white_carbon.png"]];
	
	// loaded XIB, setup buttons
	UIImage *redButtonImage = [[UIImage imageNamed:@"buttonRed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *blueButtonImage = [[UIImage imageNamed:@"buttonBlue.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *grayButtonImage = [[UIImage imageNamed:@"buttonGray.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *disabledButtonImage = [[UIImage imageNamed:@"buttonDisabled.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *pressedButtonImage = [[UIImage imageNamed:@"buttonPressed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	[self.prescMainButton setBackgroundImage:redButtonImage forState:UIControlStateNormal];
	[self.prescMainButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[self.prescMainButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	[self.prescChangeButton setBackgroundImage:blueButtonImage forState:UIControlStateNormal];
	[self.prescChangeButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[self.prescChangeButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	[self.rxNormButton setBackgroundImage:grayButtonImage forState:UIControlStateNormal];
	[self.rxNormButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[self.rxNormButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	[self.versionsButton setBackgroundImage:grayButtonImage forState:UIControlStateNormal];
	[self.versionsButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[self.versionsButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	
	// tune imageView
	self.imageView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
	self.imageView.layer.borderWidth = 1.f;
	self.imageView.layer.cornerRadius = 5.f;
	self.imageView.contentMode = UIViewContentModeScaleAspectFit;
	self.imageView.backgroundColor = [UIColor blackColor];
}



#pragma mark - Layout
- (void)layoutSubviews
{
	[super layoutSubviews];
	
	prescDuration.text = [drFormatter formattedRangeForLabel:prescDuration];
	/// @todo update instructions size
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
	
}

- (void)editMed:(id)sender
{
	
}



#pragma mark - KVC
- (void)setMed:(IndivoMedication *)aMed
{
	if (aMed != med) {
		med = aMed;
		
		agentName.text = med.name.text;
		prescName.text = med.brandName.text;
		
		self.drFormatter.from = med.dateStarted.date;
		self.drFormatter.to = med.dateStopped.date;
	}
}

- (INDateRangeFormatter *)drFormatter
{
	if (!drFormatter) {
		self.drFormatter = [INDateRangeFormatter new];
	}
	return drFormatter;
}


@end
