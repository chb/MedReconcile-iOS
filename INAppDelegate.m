//
//  INAppDelegate.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/28/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INAppDelegate.h"
#import "IndivoServer.h"
#import "INMedListController.h"

@implementation INAppDelegate

@synthesize indivo;
@synthesize window, medListController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	// create Indivo Instance
	self.indivo = [IndivoServer serverWithDelegate:self];
	
	// determine appearance
	[[UINavigationBar appearance] setTintColor:[self naviTintColor]];
	
    // create med list controller
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    self.medListController = [INMedListController new];
	} else {
	    self.medListController = [INMedListController new];
	}
	
	// wrap in a navi controller
	self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:medListController];
    [self.window makeKeyAndVisible];
	
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	/*
	 Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	 Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	 */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	/*
	 Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	 If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	 */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	/*
	 Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	 */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	/*
	 Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	 */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/*
	 Called when the application is about to terminate.
	 Save data if appropriate.
	 See also applicationDidEnterBackground:.
	 */
}



#pragma mark - Indivo Server Delegate
- (UIViewController *)viewControllerToPresentLoginViewController:(IndivoLoginViewController *)loginViewController
{
	return window.rootViewController;
}

- (void)userDidLogout:(IndivoServer *)fromServer
{
	medListController.record = nil;
	[medListController reloadList:nil];
}



#pragma mark - Utilities
/**
 *  Returns the tint color for navigation bars used throughout our app
 */
- (UIColor *)naviTintColor
{
	return [UIColor colorWithRed:0.5f green:0.15f blue:0.f alpha:1.f];
}


@end
