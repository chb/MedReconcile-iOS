//
//  INRxNormLoader.h
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/15/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INURLLoader.h"


/**
 *  Helper to load content from RxNorm's REST interface
 */
@interface INRxNormLoader : INURLLoader

@property (nonatomic, readonly, strong) NSMutableArray *responseObjects;

+ (id)loader;

- (void)getSuggestionsFor:(NSString *)searchString callback:(INCancelErrorBlock)callback;
- (void)getRelated:(NSString *)relType forId:(NSString *)rxcui callback:(INCancelErrorBlock)callback;


@end
