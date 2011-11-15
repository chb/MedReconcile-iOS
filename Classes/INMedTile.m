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

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *statusView;
@property (nonatomic, strong) UILabel *nameLabel;

@end


@implementation INMedTile

@synthesize med;
@synthesize container;
@synthesize imageView, statusView, nameLabel;


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
		self.layer.borderColor = [[UIColor blackColor] CGColor];
		self.layer.borderWidth = 1.f;
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
	CGSize size = [self bounds].size;
	
	// image
	CGFloat sixth = roundf(size.height / 6);
	CGFloat imgWidth = roundf(size.height / 3);
	CGRect imgFrame = CGRectMake(15.f, sixth, imgWidth, imgWidth);
	self.imageView.frame = imgFrame;
	
	// name label
	CGRect lblFrame = CGRectMake(15.f, imgFrame.origin.y + imgFrame.size.height + roundf(sixth/2), size.width - 30.f, imgWidth);
	self.nameLabel.frame = lblFrame;
}



#pragma mark - Action Handling
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
	//	nameLabel.adjustsFontSizeToFitWidth = YES;
		nameLabel.minimumFontSize = 10.f;
		[self addSubview:nameLabel];
	}
	return nameLabel;
}


@end
