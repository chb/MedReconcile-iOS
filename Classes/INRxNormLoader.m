//
//  INRxNormLoader.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/15/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INRxNormLoader.h"
#import "INXMLNode.h"
#import "INXMLParser.h"


@interface INRxNormLoader ()

@property (nonatomic, readwrite, strong) NSMutableDictionary *related;

@end


@implementation INRxNormLoader

@synthesize related;


+ (id)loader
{
	return [self loaderWithURL:nil];
}

/**
 *	Creates a call to http://rxnav.nlm.nih.gov/REST/rxcui/<rxcui>/related?tty=<relType>
 */
- (void)getRelated:(NSString *)relType forId:(NSString *)rxcui callback:(INCancelErrorBlock)callback
{
	if (!rxcui) {
		if (callback) {
			callback(NO, @"No rxcui given");
		}
		return;
	}
	
	// create the URL
	NSString *allRel = relType ? [NSString stringWithFormat:@"related?tty=%@", relType] : @"allrelated";
	NSString *urlString = [NSString stringWithFormat:@"http://rxnav.nlm.nih.gov/REST/rxcui/%@/%@", rxcui, allRel];
	DLog(@"-->  %@", urlString);
	self.url = [NSURL URLWithString:urlString];
	
	// load
	[self getWithCallback:^(BOOL didCancel, NSString *errorString) {
		self.related = nil;
		NSString *myErrString = nil;
		
		// got some suggestions!
		if (!errorString) {
			NSError *error = nil;
			INXMLNode *body = [INXMLParser parseXML:self.responseString error:&error];
			
			// parsed successfully, drill down
			if (body) {
				NSArray *concepts = [[body childNamed:@"relatedGroup"] childrenNamed:@"conceptGroup"];
				if ([concepts count] > 0) {
					NSMutableDictionary *found = [NSMutableDictionary dictionaryWithCapacity:[concepts count]];
					
					for (INXMLNode *conceptGroup in concepts) {
						NSString *tty = [[conceptGroup childNamed:@"tty"] text];
						NSArray *propertyNodes = [conceptGroup childrenNamed:@"conceptProperties"];
						
						// loop the properties
						if ([propertyNodes count] > 0) {
							for (INXMLNode *property in propertyNodes) {
								NSString *rxcui = [[property childNamed:@"rxcui"] text];
								NSString *name = [[property childNamed:@"name"] text];
								DLog(@"==>  %@: %@", tty, name);
								
								NSDictionary *props = [NSDictionary dictionaryWithObjectsAndKeys:rxcui, @"rxcui", name, @"name", nil];
								NSMutableArray *ttyArr = [found objectForKey:tty];
								if (!ttyArr) {
									ttyArr = [NSMutableArray array];
									[found setObject:ttyArr forKey:tty];
								}
								[ttyArr addObject:props];
							}
						}
					}
					
					self.related = found;
				}
				else {
					myErrString = [NSString stringWithFormat:@"No relatedGroup > conceptGroup nesting found in %@", body];
				}
			}
			else {
				myErrString = [NSString stringWithFormat:@"Error Parsing: %@", [error localizedDescription]];
			}
		}
		else {
			myErrString = errorString;
		}
		
		// callback
		if (callback) {
			callback(didCancel, myErrString);
		}
	}];
}


@end
