//
//  INMedContainer.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kINMedContainerAnimDuration 0.3


@class INMedTile;
@class INMedDetailTile;


/**
 *	Container view to display INMedTile view objects.
 *	If you add non-INMedTile/INMedDetailTile views to this view, the behavior is undefined
 */
@interface INMedContainer : UIScrollView

@property (nonatomic, assign) UIViewController *viewController;
@property (nonatomic, strong) INMedDetailTile *detailTile;				///< Only one detail tile at a time can be shown

- (void)showMeds:(NSArray *)medArray animated:(BOOL)animated;
- (void)addTile:(INMedTile *)aTile;
- (void)addDetailTile:(INMedDetailTile *)aDetailTile forTile:(INMedTile *)aTile animated:(BOOL)animated;
- (void)removeDetailTileAnimated:(BOOL)animated;
- (void)removeDetailTile:(id)sender;
- (void)scrollDetailTileVisibleAnimated:(BOOL)animated;

- (void)dimAllBut:(INMedTile *)aTile;
- (void)undimAll;
- (void)rearrangeByMedList:(NSArray *)medList animated:(BOOL)animated;


@end
