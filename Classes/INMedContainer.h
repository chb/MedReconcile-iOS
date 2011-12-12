//
//  INMedContainer.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class INMedTile;
@class INMedDetailTile;


/**
 *	Container view to display INMedTile view objects.
 *	If you add non-INMedTile/INMedDetailTile views to this view, the behavior is undefined
 */
@interface INMedContainer : UIScrollView

@property (nonatomic, strong) INMedDetailTile *detailTile;				///< Only one detail tile at a time can be shown

- (void)showTiles:(NSArray *)tileArray;
- (void)addTile:(INMedTile *)aTile;
- (void)addDetailTile:(INMedDetailTile *)aDetailTile forTile:(INMedTile *)aTile animated:(BOOL)animated;
- (void)removeDetailTile;

- (void)dimAllBut:(INMedTile *)aTile;
- (void)undimAll;
- (void)rearrangeByPropertyName:(NSString *)aProperty;


@end
