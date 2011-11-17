//
//  INMedContainer.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class INMedTile;


/**
 *	Container view to display INMedTile view objects.
 *	If you add non-INMedTile views to this view, the behavior is undefined
 */
@interface INMedContainer : UIView

- (void)showTiles:(NSArray *)tileArray;
- (void)addTile:(INMedTile *)aTile;

- (void)dimAllBut:(INMedTile *)aTile;
- (void)undimAll;
- (void)rearrangeByPropertyName:(NSString *)aProperty;


@end
