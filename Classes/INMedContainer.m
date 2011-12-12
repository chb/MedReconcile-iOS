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
		self.showsHorizontalScrollIndicator = NO;
	}
	return self;
}


- (void)layoutSubviewsAnimated:(BOOL)animated
{
	[self layoutSubviews];
}

- (void)layoutSubviews
{
	CGFloat myWidth = [self bounds].size.width;
	NSUInteger perRow = 2;								/// @todo determine based on view width
	CGFloat tileWidth = roundf(myWidth / perRow);		/// @todo compensate for rounded pixels
	CGFloat tileHeight = 90.f;
	
	CGFloat y = 0.f;
	CGFloat lastBottom = 0.f;
	NSUInteger tileNum = 0;
	INMedTile *lastTile = nil;
	
	for (UIView *tile in [self subviews]) {
		CGRect tileFrame = tile.frame;
		
		// a tile
		if ([tile isKindOfClass:[INMedTile class]]) {
			if (tileNum > 0 && 0 == tileNum % perRow) {
				y = lastBottom;
			}
			tileFrame.origin = CGPointMake((0 == tileNum % perRow) ? 0.f : tileWidth, y);
			tileFrame.size = CGSizeMake(tileWidth, tileHeight);
			tile.frame = tileFrame;
			
			lastTile = (INMedTile *)tile;
			tileNum++;
			
			lastBottom = fmaxf(lastBottom, tileFrame.origin.y + tileFrame.size.height);
		}
		
		// the detail tile
		else if ([tile isKindOfClass:[INMedDetailTile class]]) {
			tileFrame.origin.y = y + tileHeight;
			tileFrame.size.width = myWidth;
			tile.frame = tileFrame;
			
			lastBottom = fmaxf(lastBottom, tileFrame.origin.y + tileFrame.size.height);
		}
	}
	
	// if we have an uneven number, stretch the last one
	if (0 != tileNum % perRow) {
		CGRect lastTileFrame = lastTile.frame;
		lastTileFrame.size.width = myWidth;
		lastTile.frame = lastTileFrame;
	}
	
	// bottom shadow
	CGRect shadowFrame = self.bottomShadow.frame;
	shadowFrame.origin = CGPointMake(0.f, lastBottom);
	shadowFrame.size.width = myWidth;
	bottomShadow.frame = shadowFrame;
	
	// aaand our own height (the bottom shadow overflows)
	self.contentSize = CGSizeMake(myWidth, lastBottom);
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
- (void)addDetailTile:(INMedDetailTile *)aDetailTile forTile:(INMedTile *)aTile animated:(BOOL)animated
{
	if (aDetailTile == detailTile) {
		if (aTile != aDetailTile.forTile) {
			/// @todo Move to correct position and scroll visible
		}
		return;
	}
	[self removeDetailTile];
	
	// add detail tile
	self.detailTile = aDetailTile;
	if ([[self subviews] count] > 0) {
		if (![[self subviews] containsObject:aTile]) {
			aTile = [[self subviews] lastObject];
		}
		detailTile.forTile = aTile;
		[self insertSubview:aDetailTile aboveSubview:aTile];
	}
	else {
		[self addSubview:aDetailTile];
	}
	[self layoutSubviewsAnimated:animated];
	
	// scroll visible
	CGRect targetRect = detailTile.forTile.frame;
	targetRect.size.height += [aDetailTile frame].size.height;
	[self scrollRectToVisible:targetRect animated:animated];
}

- (void)removeDetailTile
{
	if (self == [detailTile superview]) {
		detailTile.forTile = nil;
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
		
		// prevent frame animation
		bottomShadow.actions = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"position"];
		
		[self.layer addSublayer:bottomShadow];
	}
	return bottomShadow;
}


@end
