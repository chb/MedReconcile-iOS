//
//  INTableSection.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/9/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface INTableSection : NSObject

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *title;

@property (nonatomic, assign, getter=isCollapsed) BOOL collapsed;
@property (nonatomic, readonly, strong) NSMutableArray *objects;
@property (nonatomic, strong) id selectedObject;


+ (INTableSection *)sectionWithTitle:(NSString *)aTitle;
+ (INTableSection *)sectionWithType:(NSString *)aType;

- (NSUInteger)numRows;

- (void)showIndicator;
- (void)hideIndicator;
- (UIView *)accessoryViewForRow:(NSUInteger)row;

- (void)removeAllObjects;
- (void)addObject:(id)anObject;
- (void)addObjects:(NSArray *)objects;
- (void)unshiftObject:(id)anObject;
- (void)setObjectsFrom:(NSArray *)anArray;

- (id)objectForRow:(NSUInteger)row;

- (void)addToTable:(UITableView *)aTable asSection:(NSUInteger)section animated:(BOOL)animated;
- (BOOL)hasTable;

- (void)expandAnimated:(BOOL)animated;
- (void)collapseAnimated:(BOOL)animated;
- (void)removeAnimated:(BOOL)animated;
- (void)updateAnimated:(BOOL)animated;


@end
