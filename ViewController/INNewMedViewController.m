//
//  INNewMedViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/31/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INNewMedViewController.h"
#import "INURLFetcher.h"
#import "INURLLoader.h"
#import "INXMLParser.h"
#import "INXMLNode.h"
#import "NSArray+NilProtection.h"


@interface INNewMedViewController ()

@property (nonatomic, strong) NSMutableArray *suggestions;							///< A 2d array with suggestions per level
@property (nonatomic, strong) NSMutableDictionary *suggested;						///< An dictionary with the selected suggestion (INXMLNode) per level (NSNumber)
@property (nonatomic, strong) NSMutableDictionary *suggestionsExpanded;				///< Dictionary containing BOOL-NSNumbers
@property (nonatomic, strong) NSMutableDictionary *suggestionsHeaders;				///< Dictionary containing NSStrings for NSNumber keys
@property (nonatomic, assign) NSUInteger showLoadingIndicatorAtSection;				///< The active level
@property (nonatomic, copy) NSString *currentMedString;								///< The string for which suggestions are being loaded
@property (nonatomic, strong) NSMutableDictionary *currentScores;					///< A dictionary containing approxMatch scores

@property (nonatomic, assign) NSInteger showLoadingSuggestionsIndicator;			///< If >0 shows an indicator that we are loading suggestions
@property (nonatomic, strong) UIView *suggestionHeaderView;
@property (nonatomic, strong) UILabel *loadingTextLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingActivity;

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString;
- (void)clearSuggestions;
- (void)proceedWith:(INXMLNode *)aNode fromLevel:(NSUInteger)fromLevel;

- (void)goToLevel:(NSUInteger)level;
- (void)updateSuggestionLevel:(NSUInteger)level animated:(BOOL)animated;
- (void)addSuggestionLevel:(NSUInteger)level animated:(BOOL)animated;
- (void)expandSuggestionLevel:(NSUInteger)level animated:(BOOL)animated;
- (void)collapseSuggestionLevel:(NSUInteger)level animated:(BOOL)animated;
- (void)removeSuggestionLevel:(NSUInteger)level animated:(BOOL)animated;

- (UIView *)suggestionHeader;
- (void)updateSuggestionHeader;

- (NSString *)displayNameFor:(INXMLNode *)drugNode;

@end


@implementation INNewMedViewController

@synthesize suggestions, suggested, showLoadingIndicatorAtSection, suggestionsExpanded, suggestionsHeaders, currentMedString, currentScores;
@synthesize showLoadingSuggestionsIndicator, suggestionHeaderView, loadingTextLabel, loadingActivity;


- (id)init
{
	return [self initWithNibName:nil bundle:nil];
}

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)aBundle
{
    if ((self = [super initWithNibName:nibName bundle:aBundle])) {
		self.title = @"New Medication";
		self.suggestions = [NSMutableArray arrayWithCapacity:5];
		[suggestions addObject:[NSNull null]];
		self.suggested = [NSMutableDictionary dictionaryWithCapacity:5];
		self.suggestionsExpanded = [NSMutableDictionary dictionaryWithCapacity:5];
		self.suggestionsHeaders = [NSMutableDictionary dictionary];
		self.currentScores = [NSMutableDictionary dictionaryWithCapacity:20];
    }
    return self;
}



#pragma mark - Table View Data Source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return [suggestions count];
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	if (0 == section) {
		return 1;
	}
	
	if (section < [suggestions count]) {
		if ([[suggestionsExpanded objectForKey:[NSNumber numberWithInteger:section]] boolValue]) {
			return [[suggestions objectAtIndex:section] count];
		}
		return 1;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section > 0) {
		return [suggestionsHeaders objectForKey:[NSNumber numberWithInteger:section]];
	}
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section > 0 && (showLoadingIndicatorAtSection == section || [suggestionsHeaders objectForKey:[NSNumber numberWithInteger:section]])) {
		return 28.f;
	}
	return 0.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (section > 0 && showLoadingIndicatorAtSection == section) {
		return [self suggestionHeader];
	}
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	NSString *ident = (0 == indexPath.section) ? @"InputCell" : @"SuggCell";
	cell = [aTableView dequeueReusableCellWithIdentifier:ident];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:((0 == indexPath.section) ? UITableViewCellStyleDefault : UITableViewCellStyleValue1) reuseIdentifier:ident];
		cell.textLabel.adjustsFontSizeToFitWidth = YES;
		cell.textLabel.minimumFontSize = 10.f;
	}
	
	// name input field
	if (0 == indexPath.section) {
		UITextField *textField = (UITextField *)[[cell contentView] viewWithTag:99];
		
		// create the text input if it's not here
		if (![textField isKindOfClass:[UITextField class]]) {
			textField = [[UITextField alloc] initWithFrame:CGRectInset([cell bounds], 10.f, 2.f)];
			textField.tag = 99;
			textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
			textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			textField.enablesReturnKeyAutomatically = NO;
			textField.returnKeyType = UIReturnKeyDone;
			textField.clearButtonMode = UITextFieldViewModeAlways;
			textField.autocorrectionType = UITextAutocorrectionTypeNo;
			textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			textField.placeholder = @"Medication Name";
			textField.font = [UIFont systemFontOfSize:17.f];
			textField.delegate = self;
			[cell.contentView addSubview:textField];
			
			[textField performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.0];
		}
		
	}
	
	// suggestions
	else {
		INXMLNode *drug = nil;
		NSUInteger level = indexPath.section;
		if ([[suggestionsExpanded objectForKey:[NSNumber numberWithInteger:level]] boolValue]) {
			NSArray *suggLevel = [suggestions objectOrNilAtIndex:level];
			drug = [suggLevel objectOrNilAtIndex:indexPath.row];
		}
		else {
			drug = [suggested objectForKey:[NSNumber numberWithInteger:level]];
		}
		
		cell.textLabel.text = drug ? [[drug childNamed:@"name"] text] : @"Unknown";
		cell.detailTextLabel.text = drug ? [[drug childNamed:@"tty"] text] : nil;
	}
	
	return cell;
}



#pragma mark - Table View Delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section > 0) {
		UITableViewCell *textCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
		UITextField *textField = (UITextField *)[textCell.contentView viewWithTag:99];
		[textField resignFirstResponder];
		
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		NSUInteger level = indexPath.section;
		
		// tapped an expanded level
		if ([[suggestionsExpanded objectForKey:[NSNumber numberWithInteger:level]] boolValue]) {
			NSArray *levelSugg = [suggestions objectOrNilAtIndex:level];
			INXMLNode *tappedObject = [levelSugg objectOrNilAtIndex:indexPath.row];
			
			// get the tapped node and set it selected
			if (tappedObject) {
				[suggested setObject:tappedObject forKey:[NSNumber numberWithInteger:level]];
				[self proceedWith:tappedObject fromLevel:level];
			}
			else {
				DLog(@"Ohoh, the suggestion that was tapped was not found at %@", indexPath);
			}
		}
		
		// collapsed level tapped
		else {
			[self goToLevel:level];
		}
	}
}



#pragma mark - UITextFieldDelegate
/**
 *	This method gets called whenever the text in our textfield changes. We use it to start loading medication suggestions matching the
 *	current string in the field
 */
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	NSString *current = [textField.text stringByReplacingCharactersInRange:range withString:string];
	
	// start loading suggestions
	if ([current length] > 0) {
		[self performSelector:@selector(loadSuggestionsFor:) withObject:current afterDelay:0.5];
	}
	
	// remove all suggestions
	else {
		[self clearSuggestions];
	}
	
	return YES;
}

/**
 *	Called when the user clears the field
 */
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
	[self clearSuggestions];
	return YES;
}

/**
 *	Hitting the Done key on the keyboard hides the keyboard
 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}



#pragma mark - Loading Suggestions
/**
 *	Begin to start medication suggestions for the user entered string
 */
- (void)loadSuggestionsFor:(NSString *)medString
{
	showLoadingIndicatorAtSection = 1;
	showLoadingSuggestionsIndicator = MAX(1, showLoadingSuggestionsIndicator + 1);
	//DLog(@"goto");
	[self goToLevel:1];
	
	self.currentMedString = medString;
	[currentScores removeAllObjects];
	
	// start loading suggestions
	//	NSString *apiKey = @"HELUUSPMYB";
	//	NSString *urlBase = [NSString stringWithFormat:@"http://pillbox.nlm.nih.gov/PHP/pillboxAPIService.php?key=%@", apiKey];
	NSString *urlBase = @"http://rxnav.nlm.nih.gov/REST";
	NSString *urlString = [NSString stringWithFormat:@"%@/approxMatch/%@", urlBase, [medString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSURL *url = [NSURL URLWithString:urlString];
	DLog(@"->  %@", url);
	
	INURLLoader *loader = [[INURLLoader alloc] initWithURL:url];
	[loader getWithCallback:^(BOOL didCancel, NSString *errorString) {
		showLoadingSuggestionsIndicator--;
		
		// failed
		if (errorString) {
			DLog(@"Error Loading: %@", errorString);
		}
		
		// got some suggestions!
		else {
			NSMutableArray *sugg = [suggestions objectAtIndex:1];
			[sugg removeAllObjects];
			
			// create a node with the user's entries
			INXMLNode *name = [INXMLNode nodeWithName:@"name" attributes:nil];
			name.text = medString;
			INXMLNode *myDrug = [INXMLNode nodeWithName:@"properties" attributes:nil];
			[myDrug addChild:name];
			[sugg addObject:myDrug];
			
			// parse XML
			NSError *error = nil;
			INXMLNode *body = [INXMLParser parseXML:loader.responseString error:&error];
			if (!body) {
				DLog(@"Error Parsing: %@", [error localizedDescription]);
			}
			
			// parsed successfully, drill down
			else {
				INXMLNode *list = [body childNamed:@"approxGroup"];
				if (list) {
					NSArray *suggNodes = [list childrenNamed:@"candidate"];
					
					// ok, we're down to the suggestion nodes, but we need to fetch their names
					if ([suggNodes count] > 0) {
						NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[suggNodes count]];
						
						BOOL hasMore = NO;
						NSUInteger i = 0;
						for (INXMLNode *suggestion in suggNodes) {
							if (i > 20) {
								hasMore = YES;
								break;
							}
							
							NSString *rxcui = [[suggestion childNamed:@"rxcui"] text];
							if (rxcui) {
								NSNumber *score = [NSNumber numberWithInteger:[[[suggestion childNamed:@"score"] text] integerValue]];
								if (score) {
									[currentScores setObject:score forKey:rxcui];
								}
								
								NSString *urlString = [NSString stringWithFormat:@"%@/rxcui/%@/properties", urlBase, rxcui];
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
						
						// indicate that there is more
						if (hasMore) {
							DLog(@"We have even more candidates: %d in total", [suggNodes count]);
						}
						
						// start fetching the suggestion's names
						showLoadingSuggestionsIndicator++;
						[self updateSuggestionHeader];
						
						INURLFetcher *fetcher = [INURLFetcher new];
						[fetcher getURLs:urls callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
							[self fetcher:fetcher didLoadSuggestionsFor:medString];
						}];
						return;					// to skip the table updating just yet
					}
				}
			}
		}
		
		showLoadingIndicatorAtSection = 0;
		[self updateSuggestionLevel:1 animated:YES];
	}];
}

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString
{
	showLoadingSuggestionsIndicator--;
	[self updateSuggestionHeader];
	
	if ([currentMedString isEqualToString:medString]) {
		if ([aFetcher.successfulLoads count] > 0) {
			NSMutableArray *suggIN = [NSMutableArray array];
			NSMutableArray *suggBN = [NSMutableArray array];
			NSMutableArray *suggSBD = [NSMutableArray array];
			
			// add suggestions and reload the table
			for (INURLLoader *loader in aFetcher.successfulLoads) {
				
				// parse XML
				NSError *error = nil;
				INXMLNode *node = [INXMLParser parseXML:loader.responseString error:&error];
				if (!node) {
					DLog(@"Error Parsing: %@", [error localizedDescription]);
				}
				else {
					INXMLNode *drug = [node childNamed:@"properties"];
					if (drug) {
						
						// we are going to show suggestions with type: IN (ingredient) and BN (Brand Name)
						NSString *tty = [[drug childNamed:@"tty"] text];
						DLog(@"-->  %@  [%@]  (%@, %@)", tty, [currentScores objectForKey:[[drug childNamed:@"rxcui"] text]], [[drug childNamed:@"name"] text], [[drug childNamed:@"rxcui"] text]);
						if ([tty isEqualToString:@"IN"]) {
							[suggIN addObject:drug];
						}
						else if ([tty isEqualToString:@"BN"]) {
							[suggBN addObject:drug];
						}
						else if ([tty isEqualToString:@"SBD"]) {
							[suggSBD addObject:drug];
						}
					}
				}
			}
			
			// decide which ones to use
			NSMutableArray *sugg = [suggestions objectOrNilAtIndex:1];
			if ([suggBN count] > 0) {
				[sugg addObjectsFromArray:suggBN];
			}
			else if ([suggIN count] > 0) {
				[sugg addObjectsFromArray:suggIN];
			}
			else {
				[sugg addObjectsFromArray:suggSBD];
			}
		}
		else {
			DLog(@"ALL loaders failed to load!");
		}
		
		[self updateSuggestionLevel:1 animated:YES];
	}
	else {
		DLog(@"Received suggestions for \"%@\", but we have moved on to \"%@\", discarding", medString, currentMedString);
	}
	
	showLoadingIndicatorAtSection = 0;
}


/**
 *	An RX object was selected, go to the next step
 *	The sequence is: IN -> BN -> SBD
 */
- (void)proceedWith:(INXMLNode *)aNode fromLevel:(NSUInteger)fromLevel
{
	NSString *tty = [[aNode childNamed:@"tty"] text];
	NSString *rxcui = [[aNode childNamed:@"rxcui"] text];
	
	NSString *urlBase = @"http://rxnav.nlm.nih.gov/REST";
	NSString *urlString = nil;
	if ([@"BN" isEqualToString:tty]) {
		urlString = [NSString stringWithFormat:@"%@/rxcui/%@/related?tty=SBD+DF+PIN", urlBase, rxcui];
	}
	else if ([@"IN" isEqualToString:tty]) {
		urlString = [NSString stringWithFormat:@"%@/rxcui/%@/related?tty=BN", urlBase, rxcui];
	}
	
	// continue
	if (urlString) {
		[suggestionsHeaders removeAllObjects];
		
		NSUInteger level = fromLevel + 1;
		[self goToLevel:level];
		
		showLoadingIndicatorAtSection = level;
		showLoadingSuggestionsIndicator = MAX(1, showLoadingSuggestionsIndicator);
		[self updateSuggestionHeader];
		
		DLog(@"->  %@", urlString);
		NSURL *url = [NSURL URLWithString:urlString];
		INURLLoader *loader = [[INURLLoader alloc] initWithURL:url];
		[loader getWithCallback:^(BOOL didCancel, NSString *errorString) {
			showLoadingSuggestionsIndicator--;
			[self updateSuggestionHeader];
			
			// remove suggestions further down in the hierarchy
			BOOL somethingFound = NO;
			
			
			// got some suggestions!
			if (!errorString) {
				NSError *error = nil;
				INXMLNode *body = [INXMLParser parseXML:loader.responseString error:&error];
				
				// parsed successfully, drill down
				if (body) {
					NSArray *concepts = [[body childNamed:@"relatedGroup"] childrenNamed:@"conceptGroup"];
					if ([concepts count] > 0) {
						NSMutableArray *sections = [NSMutableArray array];
						NSMutableArray *sectionNames = [NSMutableArray array];
						NSMutableArray *drugs = [NSMutableArray array];
						NSMutableArray *stripFromNames = [NSMutableArray array];
						
						for (INXMLNode *concept in concepts) {
							NSString *tty = [[concept childNamed:@"tty"] text];
							NSArray *propNodes = [concept childrenNamed:@"conceptProperties"];
							
							// loop the properties
							if ([propNodes count] > 0) {
								for (INXMLNode *main in propNodes) {
									INXMLNode *nameNode = [main childNamed:@"name"];
									NSString *name = [nameNode text];
									
									// we got a DF, dose form, use as section
									if ([@"DF" isEqualToString:tty]) {
										if (name) {
											[sections addObjectIfNotNil:[NSMutableArray array]];
											[sectionNames addObjectIfNotNil:name];
											[stripFromNames addObjectIfNotNil:name];
										}
										else {
											DLog(@"Ohoh, no name for DF found!");
										}
									}
									
									// got a PIN, precise ingredient, use to strip from names
									else if ([@"PIN" isEqualToString:tty]) {
										[stripFromNames addObjectIfNotNil:name];
									}
									
									// got a drug (BN or SBD for now)
									else {
										[drugs addObject:main];
									}
								}
							}
						}
						
						// no sections found, just add them in one
						if ([sections count] < 1) {
							[sections addObject:drugs];
						}
						
						// revisit drugs to apply grouping and name improving
						if ([drugs count] > 0) {
							somethingFound = YES;
							
							for (INXMLNode *drug in drugs) {
								INXMLNode *nameNode = [drug childNamed:@"name"];
								NSString *name = [nameNode text];
								
								// group
								NSUInteger i = 0;
								for (NSString *sectionName in sectionNames) {
									if (NSNotFound != [name rangeOfString:sectionName].location) {
										NSMutableArray *section = [sections objectAtIndex:i];
										[section addObject:drug];
									}
									i++;
								}
								
								// strip
								for (NSString *string in stripFromNames) {
									name = [name stringByReplacingOccurrencesOfString:string withString:@""];
								}
								name = [name stringByReplacingOccurrencesOfString:@"     " withString:@" "];		// gimme regex!!!! Use NSScanner one day...
								name = [name stringByReplacingOccurrencesOfString:@"    " withString:@" "];
								name = [name stringByReplacingOccurrencesOfString:@"   " withString:@" "];
								name = [name stringByReplacingOccurrencesOfString:@"  " withString:@" "];
								nameNode.text = name;
							}
							
							// update table
							[self.tableView beginUpdates];
							NSUInteger i = [suggestions count];
							while (i > level) {
								[self removeSuggestionLevel:(i - 1) animated:NO];
								i--;
							}
							i = level;
							for (NSMutableArray *section in sections) {
								[suggestions addObject:section];
								[self addSuggestionLevel:i animated:YES];
								
								NSString *sectionName = [sectionNames objectOrNilAtIndex:(i - level)];
								if (sectionName) {
									[suggestionsHeaders setObject:sectionName forKey:[NSNumber numberWithInteger:i]];
								}
								i++;
							}
							[self.tableView endUpdates];
							showLoadingIndicatorAtSection = 0;
							return;
						}
						else {
							DLog(@"Not a single drug found in concepts! %@", concepts);
						}
					}
					else {
						DLog(@"No relatedGroup > conceptGroup nesting found in %@", body);
					}
				}
				else {
					DLog(@"Error Parsing: %@", [error localizedDescription]);
				}
			}
			else {
				DLog(@"Error Loading: %@", errorString);
			}
			
			// nothing to show?
			if (!somethingFound) {
				errorString = errorString ? errorString : @"No relations found!";
				INXMLNode *fakeNode = [INXMLNode nodeWithName:@"properties" attributes:nil];
				INXMLNode *nameNode = [INXMLNode nodeWithName:@"name" attributes:nil];
				nameNode.text = errorString;
				[fakeNode addChild:nameNode];
				
				NSMutableArray *suggArray = [suggestions objectAtIndex:level];
				[suggArray addObject:fakeNode];
			}
			
			//[self.tableView reloadData];
			[self updateSuggestionLevel:level animated:NO];
		}];
	}
	
	// at last step
	else {
		DLog(@"THE END, go get: http://rxnav.nlm.nih.gov/REST/rxcui/%@/ndcs", rxcui);
	}
}



#pragma mark - Table Updating
/**
 *	Clears all suggestions
 */
- (void)clearSuggestions
{
	showLoadingIndicatorAtSection = 0;
	showLoadingSuggestionsIndicator = 0;
	[suggestions removeAllObjects];
	[suggestions addObject:[NSNull null]];
	[suggestionsHeaders removeAllObjects];
	
	[self.tableView reloadData];
}

/**
 *	Make the given level the active level
 */
- (void)goToLevel:(NSUInteger)level
{
	showLoadingIndicatorAtSection = 0;
	NSUInteger current = MAX(0, [suggestions count] - 1);
	NSUInteger i = 0;
	//DLog(@"going to level %d", level);
	
	[self.tableView beginUpdates];
	
	// we're going higher up
	if (level > current) {
		for (i = current; i < level; i++) {
			[self collapseSuggestionLevel:i animated:YES];
		}
		[self addSuggestionLevel:level animated:YES];
	}
	
	// going down, remove higher levels
	else if (current > level) {
		for (i = current; i > level; i--) {
			[self removeSuggestionLevel:i animated:NO];
		}
		[self expandSuggestionLevel:level animated:YES];
	}
	
	// staying, reload current
	else {
		[self updateSuggestionLevel:level animated:YES];
	}
	
	[self.tableView endUpdates];
}

/**
 *	Adds a given section
 */
- (void)addSuggestionLevel:(NSUInteger)level animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:level];
	
	//DLog(@"adding section %d", level);
	while ([suggestions count] <= level) {
		[suggestions addObject:[NSMutableArray array]];
	}
	[suggestionsExpanded setObject:[NSNumber numberWithBool:YES] forKey:[NSNumber numberWithInteger:level]];
	[self.tableView insertSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

/**
 *	Expands a given section
 */
- (void)expandSuggestionLevel:(NSUInteger)level animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:level];
	
	//DLog(@"expanding section %d", level);
	[suggestionsExpanded setObject:[NSNumber numberWithBool:YES] forKey:[NSNumber numberWithInteger:level]];
	[self.tableView reloadSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

/**
 *	Collapses a given section
 */
- (void)collapseSuggestionLevel:(NSUInteger)level animated:(BOOL)animated
{
	if ([[suggestionsExpanded objectForKey:[NSNumber numberWithInteger:level]] boolValue]) {
		//DLog(@"collapsing section %d", level);
		[suggestionsExpanded setObject:[NSNumber numberWithBool:NO] forKey:[NSNumber numberWithInteger:level]];
		NSMutableArray *indexes = [NSMutableArray array];
		NSUInteger row = 0;
		INXMLNode *theOne = [suggested objectForKey:[NSNumber numberWithInteger:level]];
		for (INXMLNode *node in [suggestions objectOrNilAtIndex:level]) {
			if (![node isEqual:theOne]) {
				NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:level];
				[indexes addObjectIfNotNil:indexPath];
			}
			row++;
		}
		
		[self.tableView deleteRowsAtIndexPaths:indexes withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
		[suggestionsExpanded setObject:[NSNumber numberWithBool:NO] forKey:[NSNumber numberWithInteger:level]];
	}
	else {
		//DLog(@"section %d is already collapsed", level);
	}
}

/**
 *	Removes a given section
 */
- (void)removeSuggestionLevel:(NSUInteger)level animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:level];
	
	//DLog(@"deleting section %d", level);
	while ([suggestions count] > level) {
		[suggestions removeLastObject];
	}
	[suggestionsExpanded removeObjectForKey:[NSNumber numberWithInteger:level]];
	[self.tableView deleteSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}

/**
 *	Reloads a section
 */
- (void)updateSuggestionLevel:(NSUInteger)level animated:(BOOL)animated
{
	NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:level];
	
	//DLog(@"reloading section %d", level);
	[self.tableView reloadSections:mySet withRowAnimation:(animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone)];
}


/**
 *	Starts and stops the spinner and adjusts the text
 */
- (void)updateSuggestionHeader
{
	if (showLoadingSuggestionsIndicator > 0) {
		[loadingActivity startAnimating];
		loadingTextLabel.text = @"Loading Suggestions...";
	}
	else {
		[loadingActivity stopAnimating];
		loadingTextLabel.text = @"Suggestions";
	}
}


/**
 *	Returns the loading indicator view
 */
- (UIView *)suggestionHeader
{
	[suggestionHeaderView removeFromSuperview];
	
	self.suggestionHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, 320.f, 28.f)];
	suggestionHeaderView.opaque = NO;
	suggestionHeaderView.backgroundColor = [UIColor clearColor];
	suggestionHeaderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20.f, 0.f, 280.f, 28.f)];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.opaque = NO;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont boldSystemFontOfSize:16.f];
	label.textColor = [UIColor colorWithRed:0.3f green:0.33f blue:0.42f alpha:1.f];
	label.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
	label.shadowOffset = CGSizeMake(0.f, 1.f);
	label.text = @"Suggestions";
	[suggestionHeaderView addSubview:label];
	self.loadingTextLabel = label;
	
	CGRect loadingFrame = suggestionHeaderView.frame;
	self.loadingActivity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	CGRect actFrame = loadingActivity.frame;
	actFrame.origin = CGPointMake(loadingFrame.size.width - 20.f - actFrame.size.width, 4.f);
	loadingActivity.frame = actFrame;
	loadingActivity.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[suggestionHeaderView addSubview:loadingActivity];
	
	return suggestionHeaderView;
}



#pragma mark - View lifecycle
- (void)loadView
{
	CGRect tableFrame = [[UIScreen mainScreen] applicationFrame];
	tableFrame.origin = CGPointZero;
	self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStyleGrouped];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.view = self.tableView;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return SUPPORTED_ORIENTATION(interfaceOrientation);
}



#pragma mark - Utilities
- (NSString *)displayNameFor:(INXMLNode *)drugNode
{
	if (drugNode) {
		NSString *bare = [[drugNode childNamed:@"name"] text];
		NSString *tty = [[drugNode childNamed:@"tty"] text];
		
		if ([@"SBD" isEqualToString:tty]) {
			NSArray *parts = [bare componentsSeparatedByString:@" "];
			NSInteger start = 0;
			for (NSString *part in parts) {
				if ([part length] > 2) {
					if ([@"[" isEqualToString:[part substringToIndex:1]]) {
						break;
					}
				}
				start++;
			}
			start--;
			if (start > 0) {
				NSMutableString *name = [NSMutableString string];
				NSCharacterSet *alnum = [NSCharacterSet decimalDigitCharacterSet];
				for (; start >= 0; --start) {
					NSString *part = [parts objectOrNilAtIndex:start];
					if ([part length] > 0) {
						[name insertString:@" " atIndex:0];
						[name insertString:part atIndex:0];
						
						// stop if the string is numeric
						if ([alnum isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:part]]) {
							break;
						}
					}
				}
				return name;
			}
		}
		return bare;
	}
	return @"Unknown";
}


@end
