//
//  INNewMedViewController.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 10/31/11.
//  Copyright (c) 2011 Children's Hospital Boston. All rights reserved.
//

#import "INNewMedViewController.h"
#import "INAppDelegate.h"
#import "INMedListController.h"
#import "INTableSection.h"
#import "INRxNormLoader.h"
#import "INButton.h"

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
- (void)proceedWith:(NSDictionary *)drugDict fromLevel:(NSUInteger)fromLevel;
- (void)useDrug:(NSDictionary *)drugDict;

- (INTableSection *)addSection:(INTableSection *)newSection animated:(BOOL)animated;
- (void)goToSection:(NSUInteger)sectionIdx removeLower:(BOOL)remove;

- (NSString *)displayNameFor:(INXMLNode *)drugNode;

@end


@implementation INNewMedViewController

@synthesize listController;
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
	cell.textLabel.textAlignment = UITextAlignmentLeft;
	cell.detailTextLabel.text = nil;
	cell.accessoryView = nil;
	
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
		return cell;
	}
	
	// suggestions
	INTableSection *section = [sections objectOrNilAtIndex:indexPath.section];
	if ([@"suggestion" isEqualToString:section.type] || [@"drug" isEqualToString:section.type]) {
		NSDictionary *drug = [section objectForRow:indexPath.row];
		
		cell.textLabel.text = drug ? [drug objectForKey:@"name"] : @"Unknown";
		// cell.detailTextLabel.text = [drug objectForKey:@"tty"];
		
		INButton *use = [INButton buttonWithStyle:INButtonStyleAccept];
		use.frame = CGRectMake(0.f, 0.f, 60.f, 31.f);
		[use addTarget:self action:@selector(useDrug:) forControlEvents:UIControlEventTouchUpInside];
		[use setTitle:@"Use" forState:UIControlStateNormal];
		cell.accessoryView = use;
	}
	
	// med detail nodes
	else if ([@"editable" isEqualToString:section.type]) {
		INObject *obj = [section objectForRow:indexPath.row];
		cell.textLabel.text = obj.nodeName;
		if ([obj isKindOfClass:[INDate class]]) {
			cell.detailTextLabel.text = [(INDate *)obj isoString];
		}
		else if ([obj isKindOfClass:[INCodedValue class]]) {
			cell.detailTextLabel.text = [(INCodedValue *)obj text];
		}
		else if ([obj isKindOfClass:[INUnitValue class]]) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", [(INUnitValue *)obj value] ? [(INUnitValue *)obj value] : @"?", [(INUnitValue *)obj unit].value ? [(INUnitValue *)obj unit].value : @""];
		}
		else if ([obj isKindOfClass:[IndivoMedication class]]) {
			cell.detailTextLabel.text = @"...";
		}
	}
	
	// a button
	else if ([@"button" isEqualToString:section.type]) {
		cell.textLabel.text = @"Add Medication";
		cell.textLabel.textAlignment = UITextAlignmentCenter;
		cell.detailTextLabel.text = @"";
	}
	
	//cell.accessoryView = [section accessoryViewForRow:indexPath.row];		// returns the indicator view for the active row
	
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
		id tappedObject = [section objectForRow:indexPath.row];
		
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
			
			// tapped an editable row
			else if ([@"editable" isEqualToString:section.type]) {
				INObject *obj = [section objectForRow:indexPath.row];
				
				if ([obj isKindOfClass:[INDate class]]) {
				}
				else if ([obj isKindOfClass:[INCodedValue class]]) {
				}
				else if ([obj isKindOfClass:[INUnitValue class]]) {
				}
			}
			
			// tapped the accept button, ADD MEDICATION *********************
			else if ([@"button" isEqualToString:section.type]) {
				IndivoMedication *med = [section objectForRow:indexPath.row];
				[med push:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
					if (userDidCancel) {
						
					}
					else if (errorMessage) {
						UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to add medication"
																		message:errorMessage
																	   delegate:nil
															  cancelButtonTitle:@"Too Bad"
															  otherButtonTitles:nil];
						[alert show];
					}
					else {
						
						// successfully added medication
						[listController dismissModal:nil];
					}
				}];
			}
		}
	}
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
	NSString *urlBase = @"http://rxnav.nlm.nih.gov/REST";
	NSString *urlString = [NSString stringWithFormat:@"%@/approxMatch/%@", urlBase, [medString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSURL *url = [NSURL URLWithString:urlString];
	DLog(@"->  %@", url);
	
	INURLLoader *loader = [[INURLLoader alloc] initWithURL:url];
	[loader getWithCallback:^(BOOL didCancel, NSString *errorString) {
		
		// failed
		if (errorString) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to load suggestions"
															message:errorString
														   delegate:nil
												  cancelButtonTitle:@"Too Bad"
												  otherButtonTitles:nil];
			[alert show];
			[section removeAnimated:NO];
		}
		
		// got some suggestions!
		else {
			
			// create a node with the user's entries
			NSDictionary *myDrug = [NSDictionary dictionaryWithObject:medString forKey:@"name"];
			[section addObject:myDrug];
			
			// parse XML
			NSError *error = nil;
			INXMLNode *body = [INXMLParser parseXML:loader.responseString error:&error];
			if (!body) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to parse suggestions"
																message:[error localizedDescription]
															   delegate:nil
													  cancelButtonTitle:@"Too Bad"
													  otherButtonTitles:nil];
				[alert show];
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
			[section updateAnimated:YES];
		}
		
		textField.leftView = nil;
	}];
}

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString
{
	if ([currentMedString isEqualToString:medString]) {
		INTableSection *section = [sections lastObject];
		
		// the section currently holds a representation of the user's string. If we get an exact match, remove the user's string
		NSDictionary *userSuggestion = [section.objects firstObject];
		[section removeAllObjects];
		
		// apply the names
		if ([aFetcher.successfulLoads count] > 0) {
			NSMutableArray *suggIN = [NSMutableArray array];
			NSMutableArray *suggBN = [NSMutableArray array];
			NSMutableArray *suggSBD = [NSMutableArray array];
			NSMutableArray *userSuggestionMatches = [NSMutableArray array];
			
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
						NSString *name = [[drug childNamed:@"name"] text];
						NSString *tty = [[drug childNamed:@"tty"] text];
						
						NSMutableDictionary *drugDict = [NSMutableDictionary dictionaryWithObject:tty forKey:@"tty"];
						[drugDict setObject:[[drug childNamed:@"rxcui"] text] forKey:@"rxcui"];
						[drugDict setObject:name forKey:@"name"];
						
						// if the user-entered string is exactly the same as a result, we are not going to show the user input
						if (NSOrderedSame == [name compare:[userSuggestion objectForKey:@"name"] options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)]) {
							[userSuggestionMatches addObject:drugDict];
						}
						
						// we are going to show suggestions with type: IN (ingredient) and BN (Brand Name)
						DLog(@"-->  %@  [%@]  (%@, %@)", tty, [currentScores objectForKey:[[drug childNamed:@"rxcui"] text]], name, [[drug childNamed:@"rxcui"] text]);
						if ([tty isEqualToString:@"BN"]) {
							[suggBN addObject:drugDict];
						}
						else if ([tty isEqualToString:@"IN"]) {
							[suggIN addObject:drugDict];
						}
						else if ([tty isEqualToString:@"SBD"]) {
							[suggSBD addObject:drugDict];
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
			
			// re-add the user suggestion if we're still holding on to it
			if ([userSuggestionMatches count] > 0) {
				for (NSDictionary *suggDict in userSuggestionMatches) {
					[section unshiftObject:suggDict];
				}
			}
			else if (userSuggestion) {
				[section unshiftObject:userSuggestion];
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
- (void)proceedWith:(NSDictionary *)drugDict fromLevel:(NSUInteger)fromLevel
{
	NSString *tty = [drugDict objectForKey:@"tty"];
	NSString *rxcui = [drugDict objectForKey:@"rxcui"];
	
	NSString *desired = nil;
	BOOL nowAtDrugEndpoint = NO;
	if ([@"BN" isEqualToString:tty]) {
		nowAtDrugEndpoint = YES;
		desired = @"SBD+DF+IN+PIN+SCDC";
	}
	else if ([@"IN" isEqualToString:tty]) {
		desired = @"BN";
	}
	
	// continue
	if (desired) {
		INTableSection *current = [self addSection:nil animated:YES];
		[current collapseAnimated:YES];
		[current showIndicator];
		
		INRxNormLoader *loader = [INRxNormLoader loader];
		[loader getRelated:desired forId:rxcui callback:^(BOOL didCancel, NSString *errorString) {
			BOOL somethingFound = NO;
			
			// got some data
			if (!errorString) {
				NSMutableArray *newSections = [NSMutableArray array];
				NSMutableArray *stripFromNames = [NSMutableArray array];
				NSMutableDictionary *scdc = [NSMutableDictionary dictionary];
				NSMutableArray *drugs = [NSMutableArray array];
				
				// look at what we've got
				for (NSString *tty in [loader.responseObjects allKeys]) {
					NSArray *relatedArr = [loader.responseObjects objectForKey:tty];
					for (NSDictionary *related in relatedArr) {
						NSString *name = [related objectForKey:@"name"];
						NSString *rx = [related objectForKey:@"rxcui"];
						
						// ** we got a DF, dose form, use as section (e.g. "Oral Tablet")
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
						
						// ** got IN or PIN, (precise) ingredient (e.g. "Metformin" or "Metformin hydrochloride")
						else if ([@"IN" isEqualToString:tty]) {
							[stripFromNames addObjectIfNotNil:name];
						}
						else if ([@"PIN" isEqualToString:tty]) {
							[stripFromNames unshiftObjectIfNotNil:name];
						}
						
						// ** got the SCDC, clinical drug component (e.g. "Metformin hydrochloride 500 MG")
						else if ([@"SCDC" isEqualToString:tty]) {
							if (name && rx) {
								[scdc setObject:rx forKey:name];
							}
						}
						
						// ** got a drug (BN or SBD for now)
						else {
							NSMutableDictionary *drug = [NSMutableDictionary dictionaryWithDictionary:related];
							[drug setObject:tty forKey:@"tty"];
							[drugs addObject:drug];
						}
					}
				}
				
				// no DF-sections found, just add them to one
				if ([newSections count] < 1) {
					INTableSection *lone = [INTableSection new];
					lone.type = nowAtDrugEndpoint ? @"drug" : @"suggestion";
					[newSections addObject:lone];
				}
				
				// revisit drugs to apply grouping and name improving
				if ([drugs count] > 0) {
					
					// ** loop all drugs
					for (NSMutableDictionary *drug in drugs) {
						NSString *name = [drug objectForKey:@"name"];
						[drug setObject:name forKey:@"fullName"];
						
						// use SCDC as non-branded name and for strength
						for (NSString *strength in [scdc allKeys]) {
							if (NSNotFound != [name rangeOfString:strength].location) {
								if ([drug objectForKey:@"nonbranded"]) {
									DLog(@"xx>  Found another scdc \"%@\", but already have one for drug \"%@\", skipping", strength, name);
								}
								else {
									NSDictionary *nonbranded = [NSDictionary dictionaryWithObjectsAndKeys:strength, @"name", [scdc objectForKey:strength], @"rxcui", nil];
									[drug setObject:nonbranded forKey:@"nonbranded"];
								}
								
								NSMutableString *myStrength = [drug objectForKey:@"strength"];
								if (!myStrength) {
									myStrength = [NSMutableString string];
									[drug setObject:myStrength forKey:@"strength"];
								}
								
								NSString *trimmed = strength;
								for (NSString *strip in stripFromNames) {
									trimmed = [trimmed stringByReplacingOccurrencesOfString:strip withString:@""];
								}
								trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
								if ([myStrength length] > 0) {
									[myStrength appendFormat:@"/%@", trimmed];
								}
								else {
									[myStrength setString:trimmed];
								}
							}
						}
						
						// add drug to the matching section (section = DF)
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
							DLog(@"WARNING: Drug %@ not put in any section!!!", drug);
						}
						
						// strip from names
						for (NSString *string in stripFromNames) {
							name = [name stringByReplacingOccurrencesOfString:string withString:@""];
						}
						name = [name stringByReplacingOccurrencesOfString:@"     " withString:@" "];		/// @todo Use NSScanner one day...
						name = [name stringByReplacingOccurrencesOfString:@"    " withString:@" "];
						name = [name stringByReplacingOccurrencesOfString:@"   " withString:@" "];
						name = [name stringByReplacingOccurrencesOfString:@"  " withString:@" "];
						name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						[drug setObject:name forKey:@"name"];
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
					DLog(@"Not a single drug found in concepts!");
				}
			}
			else {
				DLog(@"Error Loading: %@", errorString);
			}
			
			// nothing to show?
			if (!somethingFound) {
				errorString = errorString ? errorString : @"No relations found!";
				NSDictionary *fakeDrug = [NSDictionary dictionaryWithObject:errorString forKey:@"name"];
				
				INTableSection *newSection = [INTableSection new];
				newSection.type = @"suggestion";
				[newSection addObject:fakeDrug];
				[self addSection:newSection animated:YES];
			}
			[current hideIndicator];
		}];
	}
	
	// ok, we're happy with the selected drug, move on!
	else {
		[self useDrug:drugDict];
	}
}



#pragma mark - Drug Details
/**
 *	If a drug has been chosen, continue to the next fields
 */
- (void)useDrug:(NSDictionary *)drugDict
{
	// create medication document
	IndivoMedication *med = [IndivoMedication newWithRecord:APP_DELEGATE.indivo.activeRecord];
	if (!med) {
		DLog(@"Did not get a medication document!");
	}
	
	// name and branded name
	NSDictionary *nonbranded = [drugDict objectForKey:@"nonbranded"];
	med.name = [INCodedValue newWithNodeName:@"name"];
	if ([nonbranded objectForKey:@"rxcui"]) {
		med.name.type = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
		med.name.value = [nonbranded objectForKey:@"rxcui"];
	}
	else {
		DLog(@"NO RX IDENTIFIER FOR NONBRANDED");
	}
	med.name.text = [nonbranded objectForKey:@"name"];
	
	NSString *rxcui = [drugDict objectForKey:@"rxcui"];
	med.brandName = [INCodedValue newWithNodeName:@"brandName"];
	if (rxcui) {
		med.brandName.type = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
		med.brandName.value = rxcui;
	}
	else {
		DLog(@"NO RX IDENTIFIER FOR BRANDED");
	}
	med.brandName.text = [drugDict objectForKey:@"fullName"];
	
	/// @todo NEW SCHEMA TESTING -- dose is substitute for "formulation"
//	med.dose = [INUnitValue newWithNodeName:@"dose"];
//	med.dose.value = @"1";
//	med.dose.unit.type = @"http://indivo.org/codes/units#";
//	med.dose.unit.abbrev = @"p";
//	med.dose.unit.value = @"pills";
	
//	INTableSection *pharm = [INTableSection sectionWithType:@"editable"];
//	[pharm addObject:med.dose];
	
	// date started and stopped
	med.dateStarted = [INDate dateWithDate:[NSDate date]];
	med.dateStarted.nodeName = @"dateStarted";
	med.dateStopped = [INDate newWithNodeName:@"dateStopped"];
	
	INTableSection *dates = [INTableSection sectionWithTitle:@"Timeframe"];
	dates.type = @"editable";
	[dates addObject:med.dateStarted];
	[dates addObject:med.dateStopped];
	
	// instructions
	INTableSection *instructions = [INTableSection sectionWithTitle:@"Instructions"];
	instructions.type = @"editable";
	[instructions addObject:med];
	
	// accept button
	INTableSection *accept = [INTableSection sectionWithType:@"button"];
	[accept addObject:med];
	
	// update table
	for (INTableSection *section in sections) {
		[section collapseAnimated:YES];
	}
//	[self addSection:pharm animated:YES];
	[self addSection:dates animated:YES];
	[self addSection:instructions animated:YES];
	[self addSection:accept animated:YES];
	
	//--
	NSLog(@"\n%@\n", [med xml]);
}



#pragma mark - Table Section Updating
/**
 *	Clears all suggestions
 */
- (void)clearSuggestions
{
	NSRange mostRange = NSMakeRange(1, [sections count]-1);
	NSIndexSet *mostSections = [NSIndexSet indexSetWithIndexesInRange:mostRange];
	
	[self.tableView beginUpdates];
	[sections removeAllObjects];
	[sections addObject:[INTableSection new]];
	
	[self.tableView deleteSections:mostSections withRowAnimation:UITableViewRowAnimationBottom];
	[self.tableView endUpdates];
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
		textField.text = nil;
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
