//
//  INMedContainer.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedContainer.h"
#import <QuartzCore/QuartzCore.h>
#import "IndivoDocuments.h"
#import "INMedTile.h"
#import "INMedDetailTile.h"
#import "NSArray+NilProtection.h"


@interface INMedContainer ()

@property (nonatomic, strong) CAGradientLayer *topShadow;

- (void)layoutSubviewsAnimated:(BOOL)animated;

@end


@implementation INMedContainer

@synthesize viewController, detailTile;
@synthesize topShadow;


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		self.showsHorizontalScrollIndicator = NO;
	}
	return self;
}



#pragma mark - View Layout
/**
 *	The standard layouting method, calls layoutSubviewsAnimated:NO
 */
- (void)layoutSubviews
{
	[self layoutSubviewsAnimated:NO];
}

/**
 *	Layout subviews, optionally animated.
 */
- (void)layoutSubviewsAnimated:(BOOL)animated
{
	CGFloat myWidth = [self bounds].size.width;
	
	CGFloat minTileWidth = IS_IPAD ? 250.f : 160.f;		// min width for a tile
	NSUInteger perRow = floorf(myWidth / minTileWidth);
	CGFloat tileWidth = roundf(myWidth / perRow);
	CGFloat lastTileExtra = myWidth - (perRow * tileWidth);
	
	NSUInteger specialPerRow = perRow;
	CGFloat specialTileWidth = tileWidth;
	CGFloat lastSpecialTileExtra = lastTileExtra;
	
	CGFloat tileHeight = 70.f;
	
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
	
	// loop all subviews to count the tiles
	NSUInteger numTiles = 0;
	for (UIView *tile in [self subviews]) {
		if (66 == tile.tag || 70 == tile.tag) {
			continue;
		}
		
		// a tile
		if ([tile isKindOfClass:[INMedTile class]]) {
			numTiles++;
		}
	}
	NSUInteger specialIndex = numTiles - (numTiles % perRow);
	if (specialIndex < numTiles) {
		specialPerRow = (numTiles - specialIndex);
		specialTileWidth = roundf(myWidth / specialPerRow);
		lastSpecialTileExtra = myWidth - (specialPerRow * specialTileWidth);
	}
	
	// loop all subviews
	for (UIView *tile in [self subviews]) {
		CGRect tileFrame = tile.frame;
		
		// subviews tagged "66" are being removed and to be ignored, tagged 70 are effects views also to be ignored
		if (66 == tile.tag || 70 == tile.tag) {
			continue;
		}
		
		// a tile
		if ([tile isKindOfClass:[INMedTile class]]) {
			NSUInteger r = (tileNum % perRow);
			
			tileFrame.size.width = tileWidth;
			tileFrame.size.height = tileHeight;
			
			// advance a row
			if (0 == r) {
				y = lastBottom;
				
				// if we have an uneven number, stretch the last tile to cover the full row
				if (tile == lastTile) {
					tileFrame.size.width = myWidth;
				}
			}
			tileFrame.origin = CGPointMake(r * tileWidth, y);
			
			// special width?
			if (tileNum >= specialIndex) {
				tileFrame.size.width = specialTileWidth;
				tileFrame.origin.x = r * specialTileWidth;
				if (r + 1 == specialPerRow) {
					tileFrame.size.width += lastSpecialTileExtra;
				}
			}
			else if (r + 1 == perRow) {
				tileFrame.size.width += lastTileExtra;
			}
			
			lastBottom = fmaxf(lastBottom, tileFrame.origin.y + tileFrame.size.height);
			tileNum++;
		}
		
		// the detail tile
		else if ([tile isKindOfClass:[INMedDetailTile class]]) {
			tileFrame.origin.y = lastBottom;
			tileFrame.size.width = myWidth;
			
			lastBottom = fmaxf(lastBottom, tileFrame.origin.y + tileFrame.size.height);
		}
		
		// subviews tagged "67" have just been added and should not have an animated frame
		if (67 == tile.tag) {
			tile.frame = tileFrame;
			tile.tag = 0;
			tile.layer.opacity = 0.5f;
			tile.transform = CGAffineTransformMakeScale(3.f, 3.f);
		}
		
		// subviews tagged "68" will move to a new position
	//	else if (68 == tile.tag) {
	//		tile.transform = CGAffineTransformMakeScale(1.25f, 1.25f);
	//	}		// resetting this does not work??
		
		// set frame
		if (animated) {
			[UIView animateWithDuration:kINMedContainerAnimDuration
								  delay:0.0
								options:UIViewAnimationOptionBeginFromCurrentState
							 animations:^{
								 tile.frame = tileFrame;
								 tile.layer.opacity = 1.f;
								 if (67 == tile.tag) {
									 tile.transform = CGAffineTransformIdentity;
								 }
							 }
							 completion:NULL];
		}
		else {
			tile.frame = tileFrame;
			tile.layer.opacity = 1.f;
			tile.transform = CGAffineTransformIdentity;
		}
	}
	
	// shadow width
	topShadow.frame = CGRectMake(0.f, 0.f, myWidth, 30.f);
	
	// aaand our own height (the bottom shadow overflows)
	self.contentSize = CGSizeMake(myWidth, lastBottom);
}

- (void)didMoveToSuperview
{
	if (!topShadow) {
		[self.layer addSublayer:self.topShadow];
	}
}



#pragma mark - Adding & Removing Tiles
/**
 *	Given an array of IndivoMedication objects, creates and shows tiles for these
 */
- (void)showMeds:(NSArray *)medArray animated:(BOOL)animated
{
	[self undimAll];
	
	// no new medications, just remove old and be done with it
	if ([medArray count] < 1) {
		/// @todo Ignores animated property. Maybe fade out?
		[[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		return;
	}
	
	// collect existing tiles and remove old ones
	NSMutableArray *existing = [NSMutableArray arrayWithCapacity:[[self subviews] count]];
	for (INMedTile *tile in [self subviews]) {
		if ([tile isKindOfClass:[INMedTile class]]) {
			if ([medArray containsObject:tile.med]) {
				[existing addObject:tile];
			}
			else {
				[tile removeAnimated:animated];
			}
		}
		else if ([tile isKindOfClass:[INMedDetailTile class]]) {
			[(INMedDetailTile *)tile collapseAnimated:animated];
		}
	}
	
	// remove all and re-insert in the correct order, so layoutSubviews can do its job
	[existing makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	for (IndivoMedication *med in medArray) {
		INMedTile *tile = nil;
		for (INMedTile *existingTile in existing) {
			if ([existingTile.med isEqual:med]) {
				tile = existingTile;
				tile.med = med;
				break;
			}
		}
		if (!tile) {
			tile = [INMedTile tileWithMedication:med];
			tile.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
			tile.tag = 67;
		}
		else {
			tile.tag = 68;
		}
		[self addTile:tile];
		
		// load pill image
		if (YES || [med pillImage]) {
			[tile showImage:[med pillImage]];
		}
		else {
			[tile indicateImageAction:YES];
			[med loadPillImageBypassingCache:NO callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
				if (errorMessage) {
					DLog(@"Error loading pill image: %@", errorMessage);
				}
				[tile showImage:med.pillImage];
				[tile indicateImageAction:NO];
			}];
		}
	}
	
	// nicely lay it out
	[self layoutSubviewsAnimated:animated];
}


/**
 *	Adds a medication tile
 */
- (void)addTile:(INMedTile *)aTile
{
	aTile.container = self;
	[self addSubview:aTile];
	[self insertSubview:aTile.shadow atIndex:0];
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
	CGSize mySize = [self bounds].size;
	__block CGRect detailFrame = aDetailTile.frame;
	detailFrame.origin.y = [aTile frame].origin.y + [aTile frame].size.height;
	detailFrame.size.width = mySize.width;
	CGFloat detailOrigHeight = detailFrame.size.height;
	if (animated && !detailTile) {
		detailFrame.size.height = 2.f;
		aDetailTile.frame = detailFrame;
	}
	
	// update state
	self.detailTile = aDetailTile;
	[self dimAllBut:aTile];
	
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
		[detailTile collapseAnimated:animated];
		[self undimAll];
		self.detailTile = nil;
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



#pragma mark - KVC
/**
 *	Returns the bottom shadow layer
 */
- (CAGradientLayer *)topShadow
{
	if (!topShadow) {
		self.topShadow = [CAGradientLayer new];
		CGRect shadowFrame = CGRectMake(0.f, 0.f, [self bounds].size.width, 30.f);
		topShadow.frame = shadowFrame;
		
		// create colors
		NSMutableArray *colors = [NSMutableArray arrayWithCapacity:6];
		CGFloat alphas[] = { 0.45f, 0.3125f, 0.2f, 0.1125f, 0.05f, 0.0125f, 0.f };		// y = 0.45 x^2
		for (NSUInteger i = 0; i < 7; i++) {
			CGColorRef color = CGColorRetain([[UIColor colorWithWhite:0.f alpha:alphas[i]] CGColor]);
			[colors addObject:(__bridge_transfer id)color];
		}
		topShadow.colors = colors;
		
		// prevent frame animation
		//topShadow.actions = [NSDictionary dictionaryWithObject:[NSNull null] forKey:@"position"];
		
		[self.layer addSublayer:topShadow];
	}
	return topShadow;
}


@end
