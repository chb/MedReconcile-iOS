//
//  INAppDelegate.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/28/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IndivoServer.h"

@class IndivoServer;
@class INMedListController;


@interface INAppDelegate : UIResponder <UIApplicationDelegate, IndivoServerDelegate>

@property (nonatomic, strong) IndivoServer *indivo;

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) INMedListController *medListController;

@end
