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

@end


@implementation INMedContainer

@synthesize viewController, detailTile, bottomShadow;


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
		self.showsHorizontalScrollIndicator = NO;
	}
	return self;
}



#pragma mark - View Layout
/**
 *	The standard layouting method, does rearrange the tiles optimally
 */
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
	for (UIView *tile in [[self subviews] reverseObjectEnumerator]) {
		if ([tile isKindOfClass:[INMedTile class]]) {
			lastTile = (INMedTile *)tile;
			break;
		}
	}
	
	for (UIView *tile in [self subviews]) {
		CGRect tileFrame = tile.frame;
		
		// a tile
		if ([tile isKindOfClass:[INMedTile class]]) {
			tileFrame.size = CGSizeMake(tileWidth, tileHeight);
			
			// advance a row
			if (0 == tileNum % perRow) {
				y = lastBottom;
				
				// if we have an uneven number, stretch the last tile to cover the full row
				if (tile == lastTile) {
					tileFrame.size.width = myWidth;
				}
			}
			tileFrame.origin = CGPointMake((0 == tileNum % perRow) ? 0.f : tileWidth, y);
			tile.frame = tileFrame;
			
			lastBottom = fmaxf(lastBottom, tileFrame.origin.y + tileFrame.size.height);
			tileNum++;
		}
		
		// the detail tile
		else if ([tile isKindOfClass:[INMedDetailTile class]]) {
			tileFrame.origin.y = lastBottom;
			tileFrame.size.width = myWidth;
			tile.frame = tileFrame;
			
			lastBottom = fmaxf(lastBottom, tileFrame.origin.y + tileFrame.size.height);
		}
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
		tile.container = self;
		[self addSubview:tile];
	}
	
	[self setNeedsLayout];
}

/**
 *	Adds a medication tile
 */
- (void)addTile:(INMedTile *)aTile
{
	aTile.container = self;
	[self addSubview:aTile];
	[self setNeedsLayout];
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
	
	// find reference tile
	if (![[self subviews] containsObject:aTile]) {
		aTile = [[self subviews] lastObject];
	}
	
	// shrink frame if adding animated
	__block CGRect detailFrame = aDetailTile.frame;
	detailFrame.origin.y = [aTile frame].origin.y + [aTile frame].size.height;
	CGFloat detailOrigHeight = detailFrame.size.height;
	if (animated && !detailTile) {
		detailFrame.size.height = 10.f;
		aDetailTile.frame = detailFrame;
	}
	
	[self removeDetailTileAnimated:NO];
	self.detailTile = aDetailTile;
	
	// add subview
	if (aTile) {
		detailTile.forTile = aTile;
		aTile.showsDetailTile = YES;
		[self insertSubview:aDetailTile aboveSubview:aTile];
	}
	else {
		[self addSubview:aDetailTile];
	}
	[aDetailTile pointAtX:roundf([aTile frame].origin.x + [aTile frame].size.width / 2)];
	
	// layout
	[self layoutSubviews];
	if (animated) {
		DLog(@"Animated");
		[UIView animateWithDuration:0.2
						 animations:^{
							 detailFrame.size.height = detailOrigHeight;
							 detailTile.frame = detailFrame;
							 [self layoutSubviews];
						 }
						 completion:^(BOOL finished) {
							 [self scrollDetailTileVisibleAnimated:YES];
						 }];
	}
	else {
		[self scrollDetailTileVisibleAnimated:NO];
	}
}


/**
 *	Removes the detail tile by shrinking it, if animated is YES
 */
- (void)removeDetailTileAnimated:(BOOL)animated
{
	if (self == [detailTile superview]) {
		if (animated) {
			[UIView animateWithDuration:0.2
							 animations:^{
								 CGRect detailFrame = detailTile.frame;
								 detailFrame.size.height = 2.f;				/// @todo Do not use 0.f (makes the bg disappear immediately) until we make the background its own view
								 detailTile.frame = detailFrame;
								 [self layoutSubviews];
							 }
							 completion:^(BOOL finished) {
								 detailTile.forTile.showsDetailTile = NO;
								 detailTile.forTile = nil;
								 [detailTile removeFromSuperview];
								 self.detailTile = nil;
							 }];
		}
		else {
			detailTile.forTile.showsDetailTile = NO;
			detailTile.forTile = nil;
			[detailTile removeFromSuperview];
			self.detailTile = nil;
		}
	}
}

- (void)removeDetailTile:(id)sender
{
	[self removeDetailTileAnimated:(nil != sender)];
}


- (void)scrollDetailTileVisibleAnimated:(BOOL)animated
{
	if (detailTile) {
		CGRect targetRect = detailTile.forTile.frame;
		targetRect.size.height += [detailTile frame].size.height;
		[self scrollRectToVisible:targetRect animated:animated];
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
			[tile dimAnimated:YES];
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
			[tile undimAnimated:YES];
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
		//bottomShadow.actions = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"position"];
		
		[self.layer addSublayer:bottomShadow];
	}
	return bottomShadow;
}


@end
