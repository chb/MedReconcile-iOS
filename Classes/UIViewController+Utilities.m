//
//  UIViewController+Utilities.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/14/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "UIViewController+Utilities.h"

@implementation UIViewController (Utilities)

- (void)dismiss:(id)sender
{
	UIViewController *presenting = nil;
	if ([self respondsToSelector:@selector(presentingViewController)]) {
		presenting = [self presentingViewController];
	}
	if (!presenting && self.parentViewController) {
		presenting = self.parentViewController;
	}
	
	[presenting dismissModalViewControllerAnimated:(nil != sender)];
}


@end
