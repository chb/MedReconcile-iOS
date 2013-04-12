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
 *  A view displaying one medication as a medication tile
 */
@interface INMedTile : UIControl

@property (nonatomic, strong) IndivoMedication *med;					///< The medication we're representing
@property (nonatomic, assign) INMedContainer *container;				///< Our container view
@property (nonatomic, assign) BOOL showsDetailTile;						///< Somewhat fragile way to track whether a detail tile is shown for this tile; used by the container
@property (nonatomic, strong) UIView *shadow;							///< Can be added to the same superview but at a different level, will always have the same frame


+ (INMedTile *)tileWithMedication:(IndivoMedication *)aMed;

- (void)dimAnimated:(BOOL)animated;
- (void)undimAnimated:(BOOL)animated;
- (void)indicateAction:(BOOL)flag;

- (void)indicateImageAction:(BOOL)flag;
- (void)showImage:(UIImage *)anImage;

- (void)showMedicationDetails:(id)sender;
- (void)hideMedicationDetails:(id)sender;

- (void)removeAnimated:(BOOL)animated;


@end
