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

@end


@implementation INMedDetailTile

@synthesize med, drFormatter;
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
	
	// loaded XIB, setup buttons
	UIImage *redButtonImage = [[UIImage imageNamed:@"buttonRed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *blueButtonImage = [[UIImage imageNamed:@"buttonBlue.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *grayButtonImage = [[UIImage imageNamed:@"buttonGray.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *disabledButtonImage = [[UIImage imageNamed:@"buttonDisabled.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *pressedButtonImage = [[UIImage imageNamed:@"buttonPressed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	[t.prescMainButton setBackgroundImage:redButtonImage forState:UIControlStateNormal];
	[t.prescMainButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[t.prescMainButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	[t.prescChangeButton setBackgroundImage:blueButtonImage forState:UIControlStateNormal];
	[t.prescChangeButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[t.prescChangeButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	[t.rxNormButton setBackgroundImage:grayButtonImage forState:UIControlStateNormal];
	[t.rxNormButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[t.rxNormButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	[t.versionsButton setBackgroundImage:grayButtonImage forState:UIControlStateNormal];
	[t.versionsButton setBackgroundImage:disabledButtonImage forState:UIControlStateDisabled];
	[t.versionsButton setBackgroundImage:pressedButtonImage forState:UIControlStateHighlighted];
	
	// tune imageView
	t.imageView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
	t.imageView.layer.borderWidth = 1.f;
	t.imageView.layer.cornerRadius = 5.f;
	t.imageView.contentMode = UIViewContentModeScaleAspectFit;
	t.imageView.backgroundColor = [UIColor blackColor];
	
	return t;
}

- (id)initWithFrame:(CGRect)frame
{
	INMedDetailTile *t = [[self class] new];
	t.frame = frame;
	/// @todo how does this play with ARC??
	return t;
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
