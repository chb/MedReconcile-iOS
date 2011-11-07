//
//  INNewMedViewController.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/31/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface INNewMedViewController : UITableViewController <UITextFieldDelegate>

- (void)loadSuggestionsFor:(NSString *)medString;


@end
