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

@property (nonatomic, unsafe_unretained) UITableView *tableView;
@property (nonatomic, assign) NSInteger tableSection;

@property (nonatomic, readwrite, strong) NSMutableArray *objects;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

- (void)expandInTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated;
- (void)collapseInTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated;
- (void)removeFromTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated;
- (void)updateInTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated;

@end


@implementation INTableSection

@synthesize type;
@synthesize title;
@synthesize indicatorView;
@synthesize collapsed, objects, selectedObject;
@synthesize tableSection, tableView;


- (id)init
{
	if ((self = [super init])) {
		self.objects = [NSMutableArray array];
		tableSection = -1;
	}
	return self;
}

+ (INTableSection *)sectionWithTitle:(NSString *)aTitle
{
	INTableSection *s = [self new];
	s.title = aTitle;
	return s;
}

+ (INTableSection *)sectionWithType:(NSString *)aType
{
	INTableSection *s = [self new];
	s.type = aType;
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

- (NSString *)title
{
	if ([self numRows] < 1) {
		return nil;
	}
	return title;
}



#pragma mark - The Indicator
/**
 *	If we want an indicator shown, this method returns the indicator for the selected row, nil in all other cases
 */
- (UIView *)accessoryViewForRow:(NSUInteger)row
{
	id object = [objects objectOrNilAtIndex:row];
	if (object && [object isEqual:selectedObject]) {
		return indicatorView;
	}
	return nil;
}

/**
 *	Make sure the indicator is shown, creating it if necessary.
 *	The indicator will only be shown for the selected row, so make sure to set a selectedObject before calling this method!
 */
- (void)showIndicator
{
	if (!indicatorView) {
		self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		indicatorView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[indicatorView startAnimating];
	}
	
	// reload
	if (tableSection >= 0) {
		NSUInteger row = collapsed ? 0 : [objects indexOfObject:selectedObject];
		if (NSNotFound != row) {
			NSIndexPath *myPath = [NSIndexPath indexPathForRow:row inSection:tableSection];
			[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:myPath] withRowAnimation:UITableViewRowAnimationNone];
		}
	}
}

- (void)hideIndicator
{
	[indicatorView removeFromSuperview];
	self.indicatorView = nil;
	
	// reload
	if (tableSection >= 0) {
		NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:tableSection];
		[tableView reloadSections:mySet withRowAnimation:UITableViewRowAnimationNone];
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
 *	Adds an object to the beginning of the array
 */
- (void)unshiftObject:(id)anObject
{
	if (anObject) {
		[objects insertObject:anObject atIndex:0];
	}
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
/**
 *	Adds the receiver to the given table as section with given index
 */
- (void)addToTable:(UITableView *)aTable asSection:(NSUInteger)section animated:(BOOL)animated
{
	self.tableSection = section;
	self.tableView = aTable;
	
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	[aTable insertSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

- (BOOL)hasTable
{
	return (nil != tableView);
}

/**
 *	Expands the section to show all items, forgetting the previously selected object (if any)
 */
- (void)expandAnimated:(BOOL)animated
{
	if (tableView && tableSection >= 0) {
		[self expandInTable:tableView section:tableSection animated:animated];
	}
	else {
		DLog(@"You must add section %@ to a table first", self);
	}
}

- (void)expandInTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	
	self.collapsed = NO;
	self.selectedObject = nil;
	
	[aTable reloadSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

- (void)collapseAnimated:(BOOL)animated
{
	if (tableView && tableSection >= 0) {
		[self collapseInTable:tableView section:tableSection animated:animated];
	}
	else {
		DLog(@"You must add section %@ to a table first", self);
	}
}

- (void)collapseInTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated
{
	if (!self.collapsed) {
		self.collapsed = YES;
		
		NSMutableArray *indexes = [NSMutableArray array];
		NSUInteger row = 0;
		for (id object in objects) {
			if (![object isEqual:selectedObject]) {
				NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
				[indexes addObjectIfNotNil:indexPath];
			}
			row++;
		}
		
		[aTable deleteRowsAtIndexPaths:indexes withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
		if (!selectedObject) {
			[aTable reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
		}
	}
}

- (void)removeAnimated:(BOOL)animated
{
	if (tableView && tableSection >= 0) {
		[self removeFromTable:tableView section:tableSection animated:animated];
		self.tableSection = -1;
		self.tableView = nil;
	}
	else {
		DLog(@"You must add section %@ to a table first", self);
	}
}

- (void)removeFromTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	[aTable deleteSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
	
}

- (void)updateAnimated:(BOOL)animated
{
	if (tableView && tableSection >= 0) {
		[self updateInTable:tableView section:tableSection animated:animated];
	}
	else {
		DLog(@"You must add section %@ to a table first", self);
	}
}

- (void)updateInTable:(UITableView *)aTable section:(NSUInteger)section animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:section];
	[aTable reloadSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}



#pragma mark - Utilities
- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <0x%x>  %@, section %d, %d objects", NSStringFromClass([self class]), self, (title ? title : (type ? type : @"No title and no type")), tableSection, [objects count]];
}


@end
