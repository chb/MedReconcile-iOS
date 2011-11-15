//
//  INMedTile.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/11/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IndivoMedication;
@class INMedContainer;


/**
 *	A view displaying one medication as a medication tile
 */
@interface INMedTile : UIControl

@property (nonatomic, strong) IndivoMedication *med;
@property (nonatomic, assign) INMedContainer *container;


+ (INMedTile *)tileWithMedication:(IndivoMedication *)aMed;

- (void)showMedicationDetails:(id)sender;


@end
