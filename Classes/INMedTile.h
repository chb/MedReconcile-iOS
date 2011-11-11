//
//  INMedTile.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IndivoMedication;


/**
 *	A view displaying one medication as a medication tile
 */
@interface INMedTile : UIView

@property (nonatomic, strong) IndivoMedication *med;

+ (INMedTile *)tileWithMedication:(IndivoMedication *)aMed;


@end
