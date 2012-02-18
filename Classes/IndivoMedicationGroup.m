//
//  IndivoMedicationGroup.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 2/17/12.
//  Copyright (c) 2012 Children's Hospital Boston. All rights reserved.
//

#import "IndivoMedicationGroup.h"
#import "IndivoMedication+Report.h"


@interface IndivoMedicationGroup ()

@property (nonatomic, strong) NSMutableArray *mutableMembers;

@end


@implementation IndivoMedicationGroup

@dynamic members;
@synthesize mutableMembers;


- (id)init
{
	if ((self = [super init])) {
		self.mutableMembers = [NSMutableArray array];
	}
	return self;
}



#pragma mark - Member Handling
- (void)addMember:(IndivoMedication *)aMed
{
	if (aMed) {
		[mutableMembers addObject:aMed];
	}
}

- (NSArray *)members
{
	return [mutableMembers copy];
}


@end
