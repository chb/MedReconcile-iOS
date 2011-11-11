//
//  INMedContainer.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INMedContainer.h"
#import "INMedTile.h"


@interface INMedContainer ()

- (void)layoutSubviewsAnimated:(BOOL)animated;

@end


@implementation INMedContainer


- (id)initWithFrame:(CGRect)aFrame
{
	if ((self = [super initWithFrame:aFrame])) {
		self.backgroundColor = [UIColor viewFlipsideBackgroundColor];
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
	CGFloat height = 60.f;
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
	if (0 != i % perRow) {
		CGRect lastFrame = lastTile.frame;
		lastFrame.size.width = [self bounds].size.width;
		lastTile.frame = lastFrame;
	}
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
 *	Rearranges the existing tiles by comparing each tile's property and sorting accordingly
 */
- (void)rearrangeByPropertyName:(NSString *)aProperty
{
	
}


@end
