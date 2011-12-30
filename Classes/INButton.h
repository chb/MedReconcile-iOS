//
//  INButton.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/14/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef enum {
	INButtonStyleStandard = 0,
	INButtonStyleMain,
	INButtonStyleAccept,
	INButtonStyleDestructive
} INButtonStyle;


@interface INButton : UIButton

@property (nonatomic, assign) INButtonStyle buttonStyle;		///< The button's style
@property (nonatomic, assign) id object;						///< Dirty way to associate an object with the button

+ (id)buttonWithStyle:(INButtonStyle)aStyle;

- (void)indicateAction:(BOOL)action;


@end
