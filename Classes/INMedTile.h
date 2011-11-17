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

- (void)dim:(BOOL)flag;
- (void)dimAnimated:(BOOL)animated;
- (void)undimAnimated:(BOOL)animated;
- (void)indicateAction:(BOOL)flag;

- (void)indicateImageAction:(BOOL)flag;
- (void)showImage:(UIImage *)anImage;


@end
