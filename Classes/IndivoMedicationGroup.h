//
//  IndivoMedicationGroup.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 2/17/12.
//  Copyright (c) 2012 Children's Hospital Boston. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IndivoMedication;


/**
 *	A class holding a bunch of related IndivoMedication objects
 */
@interface IndivoMedicationGroup : NSObject

@property (nonatomic, readonly, strong) NSArray *members;

- (void)addMember:(IndivoMedication *)aMed;


@end
