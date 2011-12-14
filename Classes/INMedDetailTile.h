//
//  INMedDetailTile.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 12/8/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IndivoMedication;
@class INMedTile;
@class INButton;


/**
 *	A view intended to be used as a detail view accompanying a INMedTile
 */
@interface INMedDetailTile : UIView

@property (nonatomic, strong) IndivoMedication *med;
@property (nonatomic, strong) INMedTile *forTile;

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) IBOutlet UILabel *agentName;
@property (nonatomic, strong) IBOutlet INButton *rxNormButton;
@property (nonatomic, strong) IBOutlet INButton *versionsButton;

@property (nonatomic, strong) IBOutlet UILabel *prescName;
@property (nonatomic, strong) IBOutlet UILabel *prescDuration;
@property (nonatomic, strong) IBOutlet UILabel *prescInstructions;
@property (nonatomic, strong) IBOutlet UILabel *prescDoctor;
@property (nonatomic, strong) IBOutlet INButton *prescMainButton;
@property (nonatomic, strong) IBOutlet INButton *prescChangeButton;

- (IBAction)showRxNormBrowser:(id)sender;
- (IBAction)showVersions:(id)sender;
- (IBAction)triggerMainAction:(id)sender;
- (IBAction)editMed:(id)sender;

- (void)indicateImageAction:(BOOL)flag;
- (void)showImage:(UIImage *)anImage;


@end
