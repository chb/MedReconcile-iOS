//
//  UIView+FirstResponder.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/16/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "UIView+FirstResponder.h"

@implementation UIView (FirstResponder)

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


@end
