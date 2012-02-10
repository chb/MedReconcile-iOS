//
//  INRxNormLoader.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 11/15/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INRxNormLoader.h"
#import "INURLFetcher.h"
#import "INXMLNode.h"
#import "INXMLParser.h"


@interface INRxNormLoader ()

@property (nonatomic, readwrite, strong) NSMutableArray responseObjects;
@property (nonatomic, strong) INURLFetcher *multiFetcher;				///< We need a handle to this guy in case we cancel the connection

@end


@implementation INRxNormLoader

NSString *const baseURL = @"http://rxnav.nlm.nih.gov/REST";

@synthesize responseObjects, multiFetcher;


+ (id)loader
{
	return [self loaderWithURL:nil];
}


/**
 *	Creates a call to http://rxnav.nlm.nih.gov/REST/approxMatch
 *	A call to approxMatch returns a list of "candidate" RxNorm objects. For all of the candidate objects, we create a call to
 *	get the properties for each. At the end of the call, "responseObjects" will contain an array full of NSDictionary objects
 *	describing a suggested match. Each match is an rxcui, tty and a name.
 */
- (void)getSuggestionsFor:(NSString *)searchString callback:(INCancelErrorBlock)callback;
{
	NSString *urlString = [NSString stringWithFormat:@"%@/approxMatch/%@", baseURL, [searchString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	DLog(@"-->  %@", urlString);
	self.url = [NSURL URLWithString:urlString];
	
	self.responseObjects = nil;
	self.multiFetcher = nil;
	__block INRxNormLoader *this = self;
	
	[self getWithCallback:^(BOOL didCancel, NSString *__autoreleasing errorString) {
		__block NSString *myErrString = nil;
		
		if (errorString) {
			myErrString = errorString;
		}
		
		// **** got some suggestions!
		else if (!didCancel) {
			
			// parse XML
			NSError *error = nil;
			INXMLNode *body = [INXMLParser parseXML:this.responseString error:&error];
			
			// parsed successfully, drill down
			if (body) {
				INXMLNode *list = [body childNamed:@"approxGroup"];
				if (list) {
					NSArray *suggNodes = [list childrenNamed:@"candidate"];
					
					// ok, we're down to the suggestion nodes, extract rxcuis
					if ([suggNodes count] > 0) {
						NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[suggNodes count]];
						
						NSUInteger i = 0;
						for (INXMLNode *suggestion in suggNodes) {
							NSString *rxcui = [[suggestion childNamed:@"rxcui"] text];
							if (rxcui) {
								//NSNumber *score = [NSNumber numberWithInteger:[[[suggestion childNamed:@"score"] text] integerValue]];
								
								// create a URL where we can fetch the suggestion's properties
								NSString *urlString = [NSString stringWithFormat:@"%@/rxcui/%@/properties", baseURL, rxcui];
								NSURL *url = [NSURL URLWithString:urlString];
								if (url && ![urls containsObject:url]) {
									[urls addObject:url];
									i++;
								}
							}
							else {
								DLog(@"Did not find the rxcui in %@", suggestion);
							}
						}
						
						// ** start fetching the suggestion's properties
						this.multiFetcher = [INURLFetcher new];
						[multiFetcher getURLs:urls callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
							NSMutableArray *found = [NSMutableArray array];
							
							if (errorMessage) {
								myErrString = errorMessage;
							}
							
							// **** did fetch all properties, parse!
							else if (!userDidCancel) {
								if ([multiFetcher.successfulLoads count] > 0) {
									NSMutableArray *suggIN = [NSMutableArray array];
									NSMutableArray *suggBN = [NSMutableArray array];
									NSMutableArray *suggSBD = [NSMutableArray array];
									NSMutableDictionary *userSuggestionMatches = [NSMutableDictionary dictionary];
									
									for (INURLLoader *loader in multiFetcher.successfulLoads) {
										
										// parse XML
										NSError *error = nil;
										INXMLNode *node = [INXMLParser parseXML:loader.responseString error:&error];
										if (!node) {
											DLog(@"Error Parsing: %@", [error localizedDescription]);
										}
										else {
											INXMLNode *drug = [node childNamed:@"properties"];
											if (drug) {
												NSString *rxcui = [[drug childNamed:@"rxcui"] text];
												NSString *name = [[drug childNamed:@"name"] text];
												NSString *tty = [[drug childNamed:@"tty"] text];
												
												NSMutableDictionary *drugDict = [NSMutableDictionary dictionaryWithObject:tty forKey:@"tty"];
												[drugDict setObject:rxcui forKey:@"rxcui"];
												[drugDict setObject:name forKey:@"name"];
												
												// if the user-entered string is exactly the same as a result, we are NOT going to show the user input
												if (NSOrderedSame == [name compare:searchString options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)]) {
													[userSuggestionMatches setObject:[NSNumber numberWithBool:YES] forKey:tty];
												}
												
												// we are going to show suggestions with type: IN (ingredient) and BN (Brand Name)
												DLog(@"--->  %@  [%@]  (%@)", tty, rxcui, name);
												if ([tty isEqualToString:@"BN"]) {
													[suggBN addObject:drugDict];
												}
												else if ([tty isEqualToString:@"IN"] || [tty isEqualToString:@"MIN"]) {
													[suggIN addObject:drugDict];
												}
												else if ([tty isEqualToString:@"SBD"]) {
													[suggSBD addObject:drugDict];
												}
											}
										}
									}
									
									// ** decide which ones to use (we are only going to show one type, the most desireable one: BN > (M)IN > SBD)
									NSString *didUse = nil;
									if ([suggBN count] > 0) {
										[found addObjectsFromArray:suggBN];
										didUse = @"BN";
									}
									else if ([suggIN count] > 0) {
										[found addObjectsFromArray:suggIN];
										didUse = @"IN";
									}
									else {
										[found addObjectsFromArray:suggSBD];
										didUse = @"SBD";
									}
									
									// add the user suggestion if we haven't found an exact match for the type we're going to show
									BOOL addUserSuggestion = YES;
									if ([userSuggestionMatches count] > 0) {
										for (NSString *suggKey in [userSuggestionMatches allKeys]) {
											if ([suggKey isEqualToString:didUse]) {
												addUserSuggestion = NO;
												break;
											}
										}
									}
									if (addUserSuggestion) {
										NSDictionary *myDrug = [NSDictionary dictionaryWithObject:searchString forKey:@"name"];
										[found insertObject:myDrug atIndex:0];
									}
								}
								else {
									DLog(@"ALL loaders failed to load!");
								}
							}
							
							// **** all done, call callback
							this.responseObjects = found;
							this.multiFetcher = nil;
							if (callback) {
								callback(userDidCancel, myErrString);
							}
						}];
						return;
					}
					else {
						DLog(@"Did not find \"candidate\" in %@", list);
						// don't return an error, we'll just have no response object
					}
				}
				else {
					DLog(@"Did not find \"approxGroup\" in %@", body);
					// don't return an error, we'll just have no response object
				}
			}
			else {
				myErrString = [error localizedDescription];
			}
		}
		
		// callback if we didn't get to load suggestion properties
		if (callback) {
			callback(didCancel, myErrString);
		}
	}];
}


/**
 *	Creates a call to http://rxnav.nlm.nih.gov/REST/rxcui/<rxcui>/related?tty=<relType>
 *	Upon return, NSDictionary objects in "responseObjects" will have "name", "rxcui", "tty" strings and the drug argument in "from".
 *	@param relType The desired type to get (e.g. IN, MIN, SCDC, ...). If nil will fetch "allrelated"
 *	@param drug A dictionary of the drug for which to get related. Must contain the keys "rxcui" and should contain "tty".
 *	@param aCallback A INCancelErrorBlock callback. When the block is called, "responseObjects" has been set already.
 */
- (void)getRelated:(NSString *)relType forId:(NSString *)rxcui callback:(INCancelErrorBlock)aCallback
{
	if (!rxcui) {
		if (aCallback) {
			aCallback(NO, @"No rxcui given");
		}
		return;
	}
	
	// create the URL
	NSString *allRel = relType ? [NSString stringWithFormat:@"related?tty=%@", relType] : @"allrelated";
	NSString *urlString = [NSString stringWithFormat:@"http://rxnav.nlm.nih.gov/REST/rxcui/%@/%@", rxcui, allRel];
	DLog(@"-->  %@", urlString);
	self.url = [NSURL URLWithString:urlString];
	
	self.responseObjects = nil;
	__block INRxNormLoader *this = self;
	
	// load
	[self getWithCallback:^(BOOL didCancel, NSString *errorString) {
		NSString *myErrString = nil;
		
		// got related items
		if (!errorString) {
			NSError *error = nil;
			INXMLNode *body = [INXMLParser parseXML:self.responseString error:&error];
			
			// parsed successfully, drill down
			if (body) {
				INXMLNode *relGroup = [body childNamed:@"relatedGroup"] ? [body childNamed:@"relatedGroup"] : [body childNamed:@"allRelatedGroup"];
				NSArray *concepts = [relGroup childrenNamed:@"conceptGroup"];
				if ([concepts count] > 0) {
					NSMutableArray *found = [NSMutableArray array];
					
					for (INXMLNode *conceptGroup in concepts) {
						NSArray *propertyNodes = [conceptGroup childrenNamed:@"conceptProperties"];
						
						// loop the properties
						if ([propertyNodes count] > 0) {
							NSString *tty = [[conceptGroup childNamed:@"tty"] text];
							
							for (INXMLNode *property in propertyNodes) {
								NSString *myRxcui = [[property childNamed:@"rxcui"] text];
								NSString *name = [[property childNamed:@"name"] text];
								DLog(@"==>  %@: %@", tty, name);
								
								NSDictionary *newDrug = [NSDictionary dictionaryWithObjectsAndKeys:myRxcui, @"rxcui", name, @"name", tty, @"tty", myRxcui, @"from", nil];
								[found addObject:newDrug];
							}
						}
					}
					
					this.responseObjects = found;
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
		if (aCallback) {
			aCallback(didCancel, myErrString);
		}
	}];
}


/*
 // strength
 NSString *strength = [drugDict objectForKey:@"strength"];
 med.strength = [INUnitValue newWithNodeName:@"strength"];
 // RxNorm units:
 //	CELLS - Cells
 //	MEQ - Milliequivalent
 //	MG - Milligram
 //	ML - Milliliter
 //	UNT - Unit
 //	% - Percent
 //	ACTUAT
 //	 and combinations thereof as fractions (e.g. CELLS/ML)
 if (strength) {
 NSString *value = strength;
 NSMutableArray *units = [NSMutableArray arrayWithCapacity:2];
 for (NSString *unit in [NSArray arrayWithObjects:@"CELLS", @"MEQ", @"MG", @"ML", @"UNT", @"%", @"ACTUAT", @"/", nil]) {
 if (NSNotFound != [value rangeOfString:unit].location) {
 [units addObject:unit];
 value = [value stringByReplacingOccurrencesOfString:unit withString:@""];
 }
 }
 med.strength.value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
 med.strength.unit.type = @"http://rxnav.nlm.nih.gov/";			// no real URL for RxNorm units...
 med.strength.unit.value = [units componentsJoinedByString:@"/"];
 }
*/

#pragma mark - Overrides
- (void)cancel
{
	if (multiFetcher) {
		[multiFetcher cancel];
		self.multiFetcher = nil;
	}
	else {
		[super cancel];
	}
}


@end
