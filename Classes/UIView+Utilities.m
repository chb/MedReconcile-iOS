//
//  UIView+Utilities.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/16/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "UIView+Utilities.h"

@implementation UIView (Utilities)

- (UIView *)findFirstResponder
{
	for (UIView *subview in [self subviews]) {
		if ([subview isFirstResponder]) {
			return subview;
		}
		else {
			UIView *first = [subview findFirstResponder];
			if (first) {
				return first;
			}
		}
	}
	
	return nil;
}


- (void)centerInSuperview
{
	CGSize size = [[self superview] bounds].size;
	CGRect myFrame = self.frame;
	myFrame.origin.x = roundf((size.width - myFrame.size.width) / 2);
	myFrame.origin.y = roundf((size.height - myFrame.size.height) / 2);
	self.frame = myFrame;
}


@end
