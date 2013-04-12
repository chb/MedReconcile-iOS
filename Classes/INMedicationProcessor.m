//
//  INMedicationProcessor.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 2/17/12.
//  Copyright (c) 2012 Children's Hospital Boston. All rights reserved.
//

#import "INMedicationProcessor.h"
#import "IndivoDocuments.h"
#import "IndivoMedicationGroup.h"
#import "INRxNormLoader.h"


void runOnMainQueue(dispatch_block_t block);


@interface INMedicationProcessor ()

@property (nonatomic, readwrite, strong) NSArray *medications;
@property (nonatomic, readwrite, strong) NSArray *processedMedGroups;

@property (nonatomic, assign) dispatch_queue_t bgQueue;
@property (nonatomic, assign) NSUInteger stage;
@property (nonatomic, strong) NSMutableArray *waitingForResources;

- (void)processMeds;
- (void)didFinishProcessingSuccessfully:(BOOL)success error:(NSError *)anError;

- (void)resourceDidArrive:(id)aResource;

@end


@implementation INMedicationProcessor

@synthesize medications, processedMedGroups, callback;
@synthesize bgQueue, stage, waitingForResources;


+ (id)newWithMedications:(NSArray *)medArray
{
	INMedicationProcessor *m = [self new];
	m.medications = medArray;
	return m;
}

- (void)processWithCallback:(INCancelErrorBlock)aCallback
{
	if (callback) {
		callback(YES, nil);
	}
	if ([medications count] < 1) {
		CANCEL_ERROR_CALLBACK_OR_LOG_ERR_STRING(callback, NO, @"No medications to process")
		return;
	}
	
	// do it!
	self.callback = aCallback;
	self.bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(bgQueue, ^{
		self.stage = 1;
		
		// perform
		DLog(@"->  PROCESS");
		[self processMeds];
	});
}



#pragma mark - Processing
/**
 *  This kicks off the heavy-lifting-machine!
 */
- (void)processMeds
{
	if ([medications count] > 0) {
		NSMutableDictionary *rxnormBin = [NSMutableDictionary dictionary];
		NSMutableArray *lonelies = [NSMutableArray array];
		
		// Stage 1: check RxNorm data
		if (stage < 2) {
			DLog(@"-->  Stage %d", stage);
			self.waitingForResources = [NSMutableArray arrayWithCapacity:[medications count]];
			for (IndivoMedication *med in medications) {
				
				// no medication code
				if (!med.drugName.identifier) {
					NSString *rxcui = nil;
					
					// infer it from brand code?
					runOnMainQueue(^{
						INRxNormLoader *loader = [INRxNormLoader new];
						[waitingForResources addObject:loader];
						[loader getRelated:@"MIN+IN" forId:rxcui callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
							
							// update medication with MIN, if available, with IN otherwise
							if (!userDidCancel && !errorMessage) {
								BOOL found = NO;
								for (NSDictionary *dict in loader.responseObjects) {
									if ([@"MIN" isEqualToString:[dict objectForKey:@"tty"]]) {
										med.drugName.system = @"rxnorm/rxcui#";
										med.drugName.identifier = [dict objectForKey:@"rxcui"];
										med.drugName.title = [dict objectForKey:@"name"];
										found = YES;
										break;
									}
								}
								if (!found) {
									for (NSDictionary *dict in loader.responseObjects) {
										if ([@"IN" isEqualToString:[dict objectForKey:@"tty"]]) {
											med.drugName.system = @"rxnorm/rxcui#";
											med.drugName.identifier = [dict objectForKey:@"rxcui"];
											med.drugName.title = [dict objectForKey:@"name"];
											found = YES;
											break;
										}
									}
								}
								
								if (found) {
									[med replace:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
										[self resourceDidArrive:loader];
									}];
									return;
								}
							}
							
							[self resourceDidArrive:loader];
						}];
					});
				}
			}
			if ([waitingForResources count] < 1) {
				self.stage = MAX(stage, 2);
			}
		}
		if (stage < 2) {
			return;
		}
		
		// put all medications into a bin per rxnorm id for brandName
		DLog(@"-->  Stage %d", stage);
		for (IndivoMedication *med in medications) {
			NSString *rxcui = med.drugName.identifier;
			if ([rxcui length] > 0) {
				IndivoMedicationGroup *grp = [rxnormBin objectForKey:rxcui];
				if (!grp) {
					grp = [IndivoMedicationGroup new];
					[rxnormBin setObject:grp forKey:rxcui];
				}
				[grp addMember:med];
			}
			
			// no rxcui
			else {
				IndivoMedicationGroup *lonely = [IndivoMedicationGroup new];
				[lonely addMember:med];
				[lonelies addObject:lonely];
			}
		}
		
		// add our real groups and be done
		[lonelies addObjectsFromArray:[rxnormBin allValues]];
		self.processedMedGroups = lonelies;
		
		[self didFinishProcessingSuccessfully:YES error:nil];
	}
}


- (void)resourceDidArrive:(id)aResource
{
	[waitingForResources removeObject:aResource];
	
	// proceed when all resources have arrived
	if ([waitingForResources count] < 1) {
		stage++;
		
		dispatch_async(bgQueue, ^{
			[self processMeds];
		});
	}
}


- (void)didFinishProcessingSuccessfully:(BOOL)success error:(NSError *)anError
{
	DLog(@"->  DID FINISH");
	
	runOnMainQueue(^{
		BOOL didCancel = !success && !anError;
		CANCEL_ERROR_CALLBACK_OR_LOG_ERR_STRING(callback, didCancel, [anError localizedDescription]);
		self.callback = nil;
	});
}


@end



void runOnMainQueue(dispatch_block_t block)
{
	if ([NSThread isMainThread]) {
		block();
	}
	else {
		dispatch_async(dispatch_get_main_queue(), block);
	}
}
