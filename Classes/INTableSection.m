//
//  INTableSection.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/9/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INTableSection.h"
#import "NSArray+NilProtection.h"


@interface INTableSection ()

@property (nonatomic, readwrite, strong) NSMutableArray *objects;
@property (nonatomic, assign) NSInteger indicatorCount;
@property (nonatomic, strong) UIView *indicatorView;
@property (nonatomic, strong) UILabel *indicatorLabel;

@property (nonatomic, assign) NSInteger lastSectionIndex;
@property (nonatomic, unsafe_unretained) UITableView *lastTable;

- (void)expandInTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated;
- (void)collapseInTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated;
- (void)removeFromTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated;
- (void)updateInTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated;

@end


@implementation INTableSection

@synthesize type;
@synthesize title, headerView;
@synthesize indicatorCount, indicatorView, indicatorLabel;
@synthesize collapsed, objects, selectedObject;
@synthesize lastSectionIndex, lastTable;


- (id)init
{
	if ((self = [super init])) {
		self.objects = [NSMutableArray array];
	}
	return self;
}

+ (INTableSection *)sectionWithTitle:(NSString *)aTitle
{
	INTableSection *s = [self new];
	s.title = aTitle;
	return s;
}


#pragma mark - Section Properties
- (NSUInteger)numRows
{
	if (collapsed) {
		return selectedObject ? 1 : 0;
	}
	return [objects count];
}

- (UIView *)headerView
{
	return indicatorView ? indicatorView : headerView;
}

- (CGFloat)headerHeight
{
	if (self.headerView) {
		return [self.headerView frame].size.height;
	}
	if (title) {
		return 28.f;
	}
	return 0.f;
}


/**
 *	Make sure the indicator is shown, creating it if necessary
 */
- (void)showIndicatorWith:(NSString *)aTitle
{
	indicatorCount = MAX(1, indicatorCount + 1);
	if (!indicatorView) {
		CGRect loadingFrame = CGRectMake(0.f, 0.f, 320.f, 28.f);
		
		self.indicatorView = [[UIView alloc] initWithFrame:loadingFrame];
		indicatorView.opaque = NO;
		indicatorView.backgroundColor = [UIColor clearColor];
		indicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		self.indicatorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.f, 0.f, 280.f, 28.f)];
		indicatorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		indicatorLabel.opaque = NO;
		indicatorLabel.backgroundColor = [UIColor clearColor];
		indicatorLabel.font = [UIFont boldSystemFontOfSize:16.f];
		indicatorLabel.textColor = [UIColor colorWithRed:0.3f green:0.33f blue:0.42f alpha:1.f];
		indicatorLabel.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		indicatorLabel.shadowOffset = CGSizeMake(0.f, 1.f);
		indicatorLabel.text = aTitle;
		[indicatorView addSubview:indicatorLabel];
		
		UIActivityIndicatorView *loadingActivity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		CGRect actFrame = loadingActivity.frame;
		actFrame.origin = CGPointMake(loadingFrame.size.width - 20.f - actFrame.size.width, 4.f);
		loadingActivity.frame = actFrame;
		loadingActivity.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[indicatorView addSubview:loadingActivity];
	}
	else {
		indicatorLabel.text = aTitle;
	}
}

- (void)hideIndicator
{
	indicatorCount--;
	if (indicatorCount <= 0) {
		[indicatorView removeFromSuperview];
		self.indicatorView = nil;
	}
}



#pragma mark - Row Properties
/**
 *	Removes all objects and clears the selected object
 */
- (void)removeAllObjects
{
	self.selectedObject = nil;
	[objects removeAllObjects];
}

/**
 *	Add an object
 */
- (void)addObject:(id)anObject
{
	[objects addObjectIfNotNil:anObject];
}

/**
 *	Adds all objects from an array
 */
- (void)addObjects:(NSArray *)newObjects
{
	[objects addObjectsFromArray:newObjects];
}

/**
 *	Removes current objects and fills content with objects from the given array
 */
- (void)setObjectsFrom:(NSArray *)anArray
{
	[objects removeAllObjects];
	[objects addObjectsFromArray:anArray];
}

/**
 *	Returns the object representing the given row
 */
- (id)objectForRow:(NSUInteger)row
{
	if (collapsed && selectedObject) {
		return selectedObject;
	}
	return [objects objectOrNilAtIndex:row];
}



#pragma mark - Adding, collapsing and removing from/in/to a table
- (void)addToTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated
{
	self.lastSectionIndex = section;
	self.lastTable = aTable;
	
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	[aTable insertSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

- (BOOL)hasTable
{
	return (nil != lastTable);
}

/**
 *	Expands the section to show all items, forgetting the previously selected object (if any)
 */
- (void)expandAnimated:(BOOL)animated
{
	if (lastTable && lastSectionIndex >= 0) {
		[self expandInTable:lastTable withIndex:lastSectionIndex animated:animated];
	}
	else {
		DLog(@"You must add the section to a table first");
	}
}

- (void)expandInTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	
	self.collapsed = NO;
	self.selectedObject = nil;
	[aTable reloadSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

- (void)collapseAnimated:(BOOL)animated
{
	if (lastTable && lastSectionIndex >= 0) {
		if (selectedObject) {
			[self collapseInTable:lastTable withIndex:lastSectionIndex animated:animated];
		}
		else {
			[self updateInTable:lastTable withIndex:lastSectionIndex animated:animated];
		}
	}
	else {
		DLog(@"You must add the section to a table first");
	}
}

- (void)collapseInTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated
{
	if (!self.collapsed) {
		self.collapsed = YES;
		
		NSMutableArray *indexes = [NSMutableArray array];
		NSUInteger row = 0;
		id theOne = [self selectedObject];
		for (id object in objects) {
			if (![object isEqual:theOne]) {
				NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
				[indexes addObjectIfNotNil:indexPath];
			}
			row++;
		}
		
		[aTable deleteRowsAtIndexPaths:indexes withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
	}
}

- (void)removeAnimated:(BOOL)animated
{
	if (lastTable && lastSectionIndex >= 0) {
		[self removeFromTable:lastTable withIndex:lastSectionIndex animated:animated];
		self.lastSectionIndex = -1;
		self.lastTable = nil;
	}
	else {
		DLog(@"You must add the section to a table first");
	}
}

- (void)removeFromTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	[aTable deleteSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
	
}

- (void)updateAnimated:(BOOL)animated
{
	if (lastTable && lastSectionIndex >= 0) {
		[self updateInTable:lastTable withIndex:lastSectionIndex animated:animated];
	}
	else {
		DLog(@"You must add the section to a table first");
	}
}

- (void)updateInTable:(UITableView *)aTable withIndex:(NSUInteger)section animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	[aTable reloadSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}



#pragma mark - Utilities
- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <0x%x>  %@, section %d, %d objects", NSStringFromClass([self class]), self, (title ? title : (type ? type : @"No title and no type")), lastSectionIndex, [objects count]];
}


@end
