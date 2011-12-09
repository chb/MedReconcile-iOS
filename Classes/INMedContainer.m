//
//  INMedContainer.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedContainer.h"
#import "INMedTile.h"
#import "INMedDetailTile.h"
#import <QuartzCore/QuartzCore.h>


@interface INMedContainer ()

@property (nonatomic, strong) CAGradientLayer *bottomShadow;

- (void)layoutSubviewsAnimated:(BOOL)animated;

@end


@implementation INMedContainer

@synthesize detailTile, bottomShadow;


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
	CGRect lastFrame = CGRectZero;
	for (INMedTile *tile in [self subviews]) {
		CGRect tileFrame = tile.frame;
		if ([tile isKindOfClass:[INMedTile class]]) {							// a tile
			tileFrame.origin = CGPointMake((0 == i % perRow) ? 0.f : width, y);
			tileFrame.size = CGSizeMake(width, height);
			tile.frame = tileFrame;
			
			lastTile = tile;
			i++;
			if (i > 0 && 0 == i % perRow) {
				y += height;
			}
		}
		else if ([tile isKindOfClass:[INMedDetailTile class]]) {				// the detail tile
			tileFrame.origin.y = y;
			tile.frame = tileFrame;
			
			y += tileFrame.size.height;
			i = 0;
		}
		lastFrame = tileFrame;
	}
	
	// if we have an uneven number, stretch the last one
	if (0 != i % perRow) {
		CGRect lastTileFrame = lastTile.frame;
		lastTileFrame.size.width = [self bounds].size.width;
		lastTile.frame = lastTileFrame;
	}
	
	// bottom shadow
	CGRect shadowFrame = self.bottomShadow.frame;
	shadowFrame.origin = CGPointMake(0.f, lastFrame.origin.y + lastFrame.size.height);
	shadowFrame.size.width = [self bounds].size.width;
	bottomShadow.frame = shadowFrame;
}

- (void)didAddSubview:(UIView *)subview
{
	/// @todo adjust shadows
}

- (void)willRemoveSubview:(UIView *)subview
{
	/// @todo adjust shadows
}



#pragma mark - Adding & Removing Tiles
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
 *	Adds a detail tile for a given tile
 */
- (void)addDetailTile:(INMedDetailTile *)aDetailTile forTile:(INMedTile *)aTile
{
	if (aDetailTile == detailTile) {
		/// @todo move to correct position
		return;
	}
	
	[self removeDetailTile];
	
	DLog(@"1: %@", [self subviews]);
	NSUInteger i = [[self subviews] indexOfObject:aTile];
	DLog(@"Index: %d", i);
	if ((i + 1) < [[self subviews] count]) {
		[self insertSubview:aDetailTile atIndex:(i + 1)];
	}
	else {
		[self addSubview:aDetailTile];
	}
	self.detailTile = aDetailTile;
	[self setNeedsLayout];
	
	DLog(@"2: %@", [self subviews]);
}

- (void)removeDetailTile
{
	if (self == [detailTile superview]) {
		[detailTile removeFromSuperview];
	}
}



#pragma mark - Dimming
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
