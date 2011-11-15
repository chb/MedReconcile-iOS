//
//  INNewMedViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/31/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INNewMedViewController.h"
#import "INAppDelegate.h"
#import "INTableSection.h"

#import "IndivoServer.h"
#import "INURLFetcher.h"
#import "INURLLoader.h"
#import "INXMLParser.h"
#import "INXMLNode.h"
#import "IndivoMedication.h"
#import "NSArray+NilProtection.h"


@interface INNewMedViewController ()

@property (nonatomic, strong) NSMutableArray *sections;								///< An array full of INTableSection objects
@property (nonatomic, copy) NSString *currentMedString;								///< The string for which suggestions are being loaded
@property (nonatomic, strong) NSMutableDictionary *currentScores;					///< A dictionary containing approxMatch scores

@property (nonatomic, strong) UILabel *loadingTextLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingActivity;

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString;
- (void)clearSuggestions;
- (void)proceedWith:(INXMLNode *)aNode fromLevel:(NSUInteger)fromLevel;
- (void)useDrug:(INXMLNode *)drugNode;

- (INTableSection *)addSection:(INTableSection *)newSection animated:(BOOL)animated;
- (void)goToSection:(NSUInteger)sectionIdx removeLower:(BOOL)remove;

- (NSString *)displayNameFor:(INXMLNode *)drugNode;

@end


@implementation INNewMedViewController

@synthesize sections;
@synthesize currentMedString, currentScores;
@synthesize loadingTextLabel, loadingActivity;


- (id)init
{
	return [self initWithNibName:nil bundle:nil];
}

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)aBundle
{
    if ((self = [super initWithNibName:nibName bundle:aBundle])) {
		self.title = @"New Medication";
		self.sections = [NSMutableArray arrayWithCapacity:8];
		[sections addObject:[INTableSection new]];
		self.currentScores = [NSMutableDictionary dictionaryWithCapacity:20];
    }
    return self;
}



#pragma mark - Table View Data Source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return [sections count];
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	if (0 == section) {
		return 1;
	}
	INTableSection *sect = [sections objectOrNilAtIndex:section];
	return [sect numRows];

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	INTableSection *sect = [sections objectOrNilAtIndex:section];
	return [sect title];
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
			textField.leftViewMode = UITextFieldViewModeAlways;
			textField.delegate = self;
			[cell.contentView addSubview:textField];
			
			[textField performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.0];
		}
	}
	
	// suggestions
	else {
		INTableSection *section = [sections objectOrNilAtIndex:indexPath.section];
		if ([@"suggestion" isEqualToString:section.type] || [@"drug" isEqualToString:section.type]) {
			INXMLNode *drug = [section objectForRow:indexPath.row];
			
			cell.textLabel.text = drug ? [[drug childNamed:@"name"] text] : @"Unknown";
			cell.detailTextLabel.text = drug ? [[drug childNamed:@"tty"] text] : nil;
		}
		else if ([@"dates" isEqualToString:section.type]) {
			INDate *date = [section objectForRow:indexPath.row];
			cell.textLabel.text = (0 == indexPath.row) ? @"Start" : @"Stop";
			cell.detailTextLabel.text = [date isoString];
		}
		cell.accessoryView = [section accessoryViewForRow:indexPath.row];
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
		INTableSection *section = [sections objectOrNilAtIndex:indexPath.section];
		INXMLNode *tappedObject = [section objectForRow:indexPath.row];
		
		// collapsed level tapped
		if ([section isCollapsed]) {
			[self goToSection:indexPath.section removeLower:(![@"drug" isEqualToString:section.type])];
		}
		
		// tapped an expanded level
		else {
			section.selectedObject = tappedObject;
			
			// tapped a suggestion row
			if ([@"suggestion" isEqualToString:section.type]) {
				if (tappedObject) {
					[self proceedWith:tappedObject fromLevel:indexPath.section];
				}
				else {
					DLog(@"Ohoh, the suggestion that was tapped was not found at %@", indexPath);
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Dead End"
																	message:@"You have hit a dead end, see debug log"
																   delegate:nil
														  cancelButtonTitle:@"Too Bad"
														  otherButtonTitles:nil];
					[alert show];
				}
			}
			
			// tapped a drug row
			else if ([@"drug" isEqualToString:section.type]) {
				[self useDrug:tappedObject];
			}
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
	[self goToSection:0 removeLower:YES];
	
	INTableSection *section = [INTableSection sectionWithType:@"suggestion"];
	INTableSection *current = [self addSection:section animated:YES];
	
	// show action
	UITextField *textField = nil;
	UITableViewCell *iCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	if (iCell) {
		textField = (UITextField *)[[iCell contentView] viewWithTag:99];
		if ([textField isKindOfClass:[UITextField class]]) {
			UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			textField.leftView = act;
			[act startAnimating];
		}
	}
	
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
		
		// failed
		if (errorString) {
			DLog(@"Error Loading: %@", errorString);
		}
		
		// got some suggestions!
		else {
			
			// create a node with the user's entries
			INXMLNode *name = [INXMLNode nodeWithName:@"name" attributes:nil];
			name.text = medString;
			INXMLNode *myDrug = [INXMLNode nodeWithName:@"properties" attributes:nil];
			[myDrug addChild:name];
			[section addObject:myDrug];
			
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
						INURLFetcher *fetcher = [INURLFetcher new];
						[fetcher getURLs:urls callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
							[current hideIndicator];
							[self fetcher:fetcher didLoadSuggestionsFor:medString];
						}];
						return;					// to skip the table updating just yet
					}
				}
			}
		}
		
		textField.leftView = nil;
		[section updateAnimated:YES];
	}];
}

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString
{
	if ([currentMedString isEqualToString:medString]) {
		INTableSection *section = [sections lastObject];
		
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
			if ([suggBN count] > 0) {
				[section addObjects:suggBN];
			}
			else if ([suggIN count] > 0) {
				[section addObjects:suggIN];
			}
			else {
				[section addObjects:suggSBD];
			}
		}
		else {
			DLog(@"ALL loaders failed to load!");
		}
		
		[section updateAnimated:YES];
	}
	else {
		DLog(@"Received suggestions for \"%@\", but we have moved on to \"%@\", discarding", medString, currentMedString);
	}
	
	// stop action
	UITableViewCell *iCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	if (iCell) {
		UITextField *textField = (UITextField *)[[iCell contentView] viewWithTag:99];
		if ([textField isKindOfClass:[UITextField class]]) {
			textField.leftView = nil;
		}
	}
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
	BOOL nowAtDrugEndpoint = NO;
	if ([@"BN" isEqualToString:tty]) {
		nowAtDrugEndpoint = YES;
		urlString = [NSString stringWithFormat:@"%@/rxcui/%@/related?tty=SBD+DF+PIN+SCDC", urlBase, rxcui];
	}
	else if ([@"IN" isEqualToString:tty]) {
		urlString = [NSString stringWithFormat:@"%@/rxcui/%@/related?tty=BN", urlBase, rxcui];
	}
	
	// continue
	if (urlString) {
		INTableSection *current = [self addSection:nil animated:YES];
		[current collapseAnimated:YES];
		[current showIndicator];
		
		DLog(@"->  %@", urlString);
		NSURL *url = [NSURL URLWithString:urlString];
		INURLLoader *loader = [[INURLLoader alloc] initWithURL:url];
		[loader getWithCallback:^(BOOL didCancel, NSString *errorString) {
			BOOL somethingFound = NO;
			
			// got some suggestions!
			if (!errorString) {
				NSError *error = nil;
				INXMLNode *body = [INXMLParser parseXML:loader.responseString error:&error];
				
				// parsed successfully, drill down
				if (body) {
					NSArray *concepts = [[body childNamed:@"relatedGroup"] childrenNamed:@"conceptGroup"];
					if ([concepts count] > 0) {
						NSMutableArray *newSections = [NSMutableArray array];
						NSMutableArray *drugs = [NSMutableArray array];
						NSMutableArray *stripFromNames = [NSMutableArray array];
						NSMutableString *strength = [NSMutableString string];
						
						for (INXMLNode *concept in concepts) {
							NSString *tty = [[concept childNamed:@"tty"] text];
							NSArray *propNodes = [concept childrenNamed:@"conceptProperties"];
							
							// loop the properties
							if ([propNodes count] > 0) {
								for (INXMLNode *main in propNodes) {
									INXMLNode *nameNode = [main childNamed:@"name"];
									NSString *name = [nameNode text];
									DLog(@"%@: %@", tty, name);
									
									// ** we got a DF, dose form, use as section
									if ([@"DF" isEqualToString:tty]) {
										if (name) {
											INTableSection *newSection = [INTableSection sectionWithTitle:name];
											newSection.type = nowAtDrugEndpoint ? @"drug" : @"suggestion";
											[newSections addObject:newSection];
											[stripFromNames addObjectIfNotNil:name];
										}
										else {
											DLog(@"Ohoh, no name for DF found!");
										}
									}
									
									// ** got a PIN, precise ingredient, use to strip from names
									else if ([@"PIN" isEqualToString:tty]) {
										[stripFromNames addObjectIfNotNil:name];
									}
									
									// ** got the SCDC, clinical drug component, strip PIN to get strength
									else if ([@"SCDC" isEqualToString:tty]) {
										[strength setString:name];
										// CAN THERE BE MULTIPLE SCDC NODES???
									}
									
									// ** got a drug (BN or SBD for now)
									else {
										[drugs addObject:main];
									}
								}
							}
						}
						
						// no DF-sections found, just add them in one
						if ([newSections count] < 1) {
							INTableSection *lone = [INTableSection new];
							lone.type = nowAtDrugEndpoint ? @"drug" : @"suggestion";
							[newSections addObject:lone];
						}
						
						// revisit drugs to apply grouping and name improving
						if ([drugs count] > 0) {
							somethingFound = YES;
							
							for (INXMLNode *drug in drugs) {
								INXMLNode *nameNode = [drug childNamed:@"name"];
								NSString *name = [nameNode text];
								INXMLNode *origName = [INXMLNode nodeWithName:@"originalName"];
								origName.text = name;
								[drug addChild:origName];
								
								// add drugs to sections
								NSUInteger i = 0;
								NSUInteger put = 0;
								for (INTableSection *section in newSections) {
									if (!section.title || NSNotFound != [name rangeOfString:section.title].location) {
										[section addObject:drug];
										put++;
									}
									i++;
								}
								if (put < 1) {
									DLog(@"Warning: Drug %@ not put in any section!!!", drug);
								}
								
								// strip from names
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
							[current hideIndicator];
							INTableSection *last = [newSections lastObject];
							for (INTableSection *section in newSections) {
								[self addSection:section animated:(section == last)];
							}
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
				
				INTableSection *newSection = [INTableSection new];
				newSection.type = @"suggestion";
				[newSection addObject:fakeNode];
				[self addSection:newSection animated:YES];
			}
			[current hideIndicator];
		}];
	}
	
	// ok, we're happy with the selected drug, move on!
	else {
		[self useDrug:aNode];
	}
}



#pragma mark - Drug Details
/**
 *	If a drug has been chosen, continue to the next fields
 */
- (void)useDrug:(INXMLNode *)drugNode
{
	// create medication document
	IndivoMedication *med = [IndivoMedication newWithRecord:APP_DELEGATE.indivo.activeRecord];
	if (!med) {
		DLog(@"Did not get a medication document!");
	}
	
	// brand name
	NSString *rxcui = [[drugNode childNamed:@"rxcui"] text];
	
	med.brandName = [INCodedValue new];
	if (rxcui) {
		med.brandName.type = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
		med.brandName.abbrev = rxcui;
	}
	else {
		DLog(@"NO RX IDENTIFIER");
	}
	med.brandName.value = [[drugNode childNamed:@"originalName"] text];
	
	// date started and stopped
	med.dateStarted = [INDate dateWithDate:[NSDate date]];
	med.dateStopped = [INDate new];
	
	INTableSection *dates = [INTableSection sectionWithTitle:@"Timeframe"];
	dates.type = @"editable";
	[dates addObject:med.dateStarted];
	[dates addObject:med.dateStopped];
	
	// dose
	med.dose = [INUnitValue new];
	med.route = [INCodedValue new];
	med.strength = [INUnitValue new];
	med.frequency = [INCodedValue new];
	
	// instructions
	INTableSection *instructions = [INTableSection sectionWithTitle:@"Instructions"];
	instructions.type = @"editable";
	[instructions addObject:drugNode];
	
	// update table
	for (INTableSection *section in sections) {
		[section collapseAnimated:YES];
	}
	[self addSection:dates animated:NO];
	[self addSection:instructions animated:YES];
}



#pragma mark - Table Section Updating
/**
 *	Clears all suggestions
 */
- (void)clearSuggestions
{
	[sections removeAllObjects];
	[sections addObject:[INTableSection new]];
	
	[self.tableView reloadData];
}

/**
 *	Pushes the given table section while returning the current section
 */
- (INTableSection *)addSection:(INTableSection *)newSection animated:(BOOL)animated
{
	INTableSection *current = [sections lastObject];
	
	// add new
	[self.tableView beginUpdates];
	if (newSection) {
		NSUInteger section = [sections count];
		[sections addObject:newSection];
		[newSection addToTable:self.tableView asSection:section animated:animated];
	}
	[self.tableView endUpdates];
	
	return current;
}

/**
 *	Make the given level the active level
 */
- (void)goToSection:(NSUInteger)sectionIdx removeLower:(BOOL)remove
{
	DLog(@"going to section %d", sectionIdx);
	[self.tableView beginUpdates];
	
	NSInteger i = [sections count] - 1;
	while (i > 0) {						// if we use > 0 we let the first row/section in peace
		INTableSection *existing = [sections objectAtIndex:i];
		
		// remove or expand higher sections
		if (i > sectionIdx) {
			if (remove || [@"suggestion" isEqualToString:existing.type] || [@"editable" isEqualToString:existing.type]) {
				DLog(@"Removing %@", existing);
				[existing removeAnimated:NO];
				[sections removeLastObject];
			}
			else {
				DLog(@"Expanding %@", existing);
				[existing expandAnimated:YES];
			}
		}
		
		// target section, expand after adding to table (if necessary)
		else if (i == sectionIdx) {
			DLog(@"Expanding current %@", existing);
			[existing expandAnimated:YES];
		}
		
		// expand or collapse lower levels
		else {
			if ([@"drug" isEqualToString:existing.type]) {
				DLog(@"Expanding %@", existing);
				[existing expandAnimated:YES];
			}
			else {
				DLog(@"Collapsing %@", existing);
				[existing collapseAnimated:YES];
			}
		}
		i--;
	}
	
	[self.tableView endUpdates];
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
