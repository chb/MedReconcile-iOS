//
//  INMedicationProcessor.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 2/17/12.
//  Copyright (c) 2012 Children's Hospital Boston. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Indivo.h"


/**
 *  A class that processes an array of medications. Specifically it:
 *  	- does this
 *  	- and that
 */
@interface INMedicationProcessor : NSObject

@property (nonatomic, readonly, strong) NSArray *medications;						///< The input array, full of IndivoMedication objects
@property (nonatomic, readonly, strong) NSArray *processedMedGroups;				///< The output array, full of IndivoMedicationGroup objects
@property (nonatomic, copy) INCancelErrorBlock callback;

+ (id)newWithMedications:(NSArray *)medArray;

- (void)processWithCallback:(INCancelErrorBlock)aCallback;


@end
