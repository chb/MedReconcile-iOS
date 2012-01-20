//
//  IndivoMedication+RxNorm.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 1/19/12.
//  Copyright (c) 2012 Children's Hospital Boston. All rights reserved.
//

#import "IndivoMedication.h"

@interface IndivoMedication (RxNorm)

+ (id)newWithRxNormDict:(NSDictionary *)aDict;
- (NSDictionary *)rxNormDict;


@end
