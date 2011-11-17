//
//  INMedContainer.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedContainer.h"
#import "INMedTile.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedContainer ()

@property (nonatomic, strong) CAGradientLayer *bottomShadow;

- (void)layoutSubviewsAnimated:(BOOL)animated;

@end


@implementation INMedContainer

@synthesize bottomShadow;


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	}
	return self;
}


- (void)layoutSubviewsAnimated:(BOOL)animated
{
	[self layoutSubviews];
}

- (void)layoutSubviews
{
	CGFloat y = 0.f;
	CGFloat height = 90.f;
	NSUInteger perRow = 2;			/// @todo determine based on view width
	CGFloat width = roundf([self bounds].size.width / perRow);			/// @todo compensate for rounded pixels
	NSUInteger i = 0;
	INMedTile *lastTile = nil;
	for (INMedTile *tile in [self subviews]) {
		if ([tile isKindOfClass:[INMedTile class]]) {
			CGRect tileFrame = tile.frame;
			if (i > 0 && 0 == i % perRow) {
				y += height;
			}
			tileFrame.origin = CGPointMake((0 == i % perRow) ? 0.f : width, y);
			tileFrame.size = CGSizeMake(width, height);
			tile.frame = tileFrame;
			
			lastTile = tile;
			i++;
		}
	}
	
	// if we have an uneven number, stretch the last one
	/// @todo this is only working for 2 per row with this cheap implementation
	CGRect lastFrame = lastTile.frame;
	if (0 != i % perRow) {
		lastFrame.size.width = [self bounds].size.width;
		lastTile.frame = lastFrame;
	}
	
	// bottom shadow
	CGRect shadowFrame = self.bottomShadow.frame;
	shadowFrame.origin = CGPointMake(0.f, lastFrame.origin.y + lastFrame.size.height);
	shadowFrame.size.width = [self bounds].size.width;
	bottomShadow.frame = shadowFrame;
}


/**
 *	Given an array of INMedTile objects, shows these tiles
 */
- (void)showTiles:(NSArray *)tileArray
{
	// remove old, add new and layout
	[[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	for (INMedTile *tile in tileArray) {
		[self addSubview:tile];
	}
	
	[self layoutSubviews];
}

/**
 *	Adds a medication tile
 */
- (void)addTile:(INMedTile *)aTile
{
	[self addSubview:aTile];
	[self layoutSubviews];
}

/**
 *	Dims all but the given tile - all if nil is given
 */
- (void)dimAllBut:(INMedTile *)aTile
{
	for (INMedTile *tile in [self subviews]) {
		if ([tile isKindOfClass:[INMedTile class]] && ![aTile isEqual:tile]) {
			[tile dim:YES];
		}
	}
}

/**
 *	Undims all tiles
 */
- (void)undimAll
{
	for (INMedTile *tile in [self subviews]) {
		if ([tile isKindOfClass:[INMedTile class]]) {
			[tile dim:NO];
		}
	}
}

/**
 *	Rearranges the existing tiles by comparing each tile's property and sorting accordingly
 */
- (void)rearrangeByPropertyName:(NSString *)aProperty
{
	
}



#pragma mark - KVC
/**
 *	Returns the bottom shadow layer
 */
- (CAGradientLayer *)bottomShadow
{
	if (!bottomShadow) {
		self.bottomShadow = [CAGradientLayer new];
		CGRect shadowFrame = CGRectMake(0.f, 0.f, [self bounds].size.width, 30.f);
		bottomShadow.frame = shadowFrame;
		
		// create colors
		NSMutableArray *colors = [NSMutableArray arrayWithCapacity:6];
		CGFloat alphas[] = { 0.45f, 0.3125f, 0.2f, 0.1125f, 0.05f, 0.0125f, 0.f };		// y = 0.45 x^2
		for (NSUInteger i = 0; i < 7; i++) {
			CGColorRef color = CGColorRetain([[UIColor colorWithWhite:0.f alpha:alphas[i]] CGColor]);
			[colors addObject:(__bridge_transfer id)color];
		}
		
		bottomShadow.colors = colors;
		[self.layer addSublayer:bottomShadow];
	}
	return bottomShadow;
}


@end
