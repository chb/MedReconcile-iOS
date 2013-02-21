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
#import "INRxNormLoader.h"
#import "IndivoMedication+RxNorm.h"
#import "INDateRangeFormatter.h"
#import "INButton.h"

#import "IndivoServer.h"
#import "INXMLParser.h"
#import "INXMLNode.h"
#import "IndivoDocuments.h"
#import "NSArray+NilProtection.h"


@interface INNewMedViewController ()

@property (nonatomic, strong) NSMutableArray *sections;								///< An array full of INTableSection objects
@property (nonatomic, strong) IndivoMedication *initialMed;							///< The rxcui from which to start. Takes precedence over initialMedString
@property (nonatomic, copy) NSString *initialMedString;								///< The string with which to start off
@property (nonatomic, copy) NSString *currentMedString;								///< The string for which suggestions are being loaded
@property (nonatomic, strong) INRxNormLoader *currentLoader;						///< A handle to the currently active loader so we can abort loading

@property (nonatomic, strong) UITextField *nameInputField;
@property (nonatomic, strong) UILabel *loadingTextLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingActivity;

- (void)clearSuggestions;
- (void)proceedWith:(NSIndexPath *)indexPath;
- (void)useDrug:(NSIndexPath *)indexPath;
- (void)useThisDrug:(INButton *)sender;

- (void)addSection:(INTableSection *)newSection animated:(BOOL)animated;
- (void)goToSection:(NSUInteger)sectionIdx animated:(BOOL)animated;

- (NSString *)displayNameFor:(INXMLNode *)drugNode;

@end


@implementation INNewMedViewController

@synthesize delegate;
@synthesize sections;
@synthesize initialMed, initialMedString, currentMedString, currentLoader;
@synthesize nameInputField, loadingTextLabel, loadingActivity;


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
		cell = [[UITableViewCell alloc] initWithStyle:((0 == indexPath.section) ? UITableViewCellStyleDefault : UITableViewCellStyleSubtitle) reuseIdentifier:ident];
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
			[cell.contentView addSubview:self.nameInputField];
			
			if (initialMed) {
				[self performSelector:@selector(loadSuggestionsForMed:) withObject:initialMed afterDelay:0.4];
			}
			else if (initialMedString) {
				nameInputField.text = initialMedString;
				[self performSelector:@selector(loadSuggestionsFor:) withObject:initialMedString afterDelay:0.4];
			}
			else {
				[nameInputField performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.0];
			}
		}
		return cell;
	}
	
	// suggestions
	INTableSection *section = [sections objectOrNilAtIndex:indexPath.section];
	id object = [section objectForRow:indexPath.row];
	
	// got a med
	if ([object isKindOfClass:[IndivoMedication class]]) {
		IndivoMedication *med = (IndivoMedication *)object;
		cell.textLabel.text = [med displayName];
		
		INDateRangeFormatter *drFormatter = [INDateRangeFormatter new];
		drFormatter.from = med.prescription.on.date;
		drFormatter.to = med.prescription.stopOn.date;
		cell.detailTextLabel.text = [drFormatter formattedRange];
		
		BOOL canUseDrug = (nil != med.record || [@"SBD" isEqualToString:med.dose.unit.abbrev] || object == [section selectedObject]);
		INButtonStyle style = canUseDrug ? INButtonStyleAccept : INButtonStyleMain;
		
		INButton *use = [INButton buttonWithStyle:style];
		use.frame = CGRectMake(0.f, 0.f, 60.f, 31.f);
		use.object = indexPath;
		[use addTarget:self action:@selector(useThisDrug:) forControlEvents:UIControlEventTouchUpInside];
		[use setTitle:(canUseDrug ? (nil != med.record ? @"Edit" : @"Use") : @"More") forState:UIControlStateNormal];
		cell.accessoryView = use;
	}
	
	// got a string
	else if ([object isKindOfClass:[NSString class]]) {
		cell.textLabel.text = (NSString *)object;
		cell.accessoryView = nil;
	}
	
	return cell;
}



#pragma mark - Table View Delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if (indexPath.section > 0) {
		[nameInputField resignFirstResponder];
		INTableSection *section = [sections objectOrNilAtIndex:indexPath.section];
		
		// collapsed level tapped
		if ([section isCollapsed]) {
			[self goToSection:indexPath.section animated:YES];
		}
		
		// tapped an expanded level
		else {
			[self proceedWith:indexPath];
		}
	}
}



#pragma mark - Loading Suggestions
/**
 *	Load medication suggestions for the user entered string
 */
- (void)loadSuggestionsFor:(NSString *)medString
{
	[self goToSection:0 animated:YES];
	
	// show action
	if (nameInputField) {
		UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		nameInputField.enabled = YES;
		nameInputField.leftView = act;
		[act startAnimating];
	}
	
	// search in patient's current meds
	if ([delegate respondsToSelector:@selector(currentMedsForNewMedController:)]) {
		NSMutableArray *existing = [NSMutableArray array];
		NSArray *currentMeds = [delegate currentMedsForNewMedController:self];
		for (IndivoMedication *current in currentMeds) {
			if ([current matchesName:medString]) {
				[existing addObject:current];
			}
		}
		
		// found existing meds that match!
		if ([existing count] > 0) {
			INTableSection *exist = [INTableSection newWithTitle:@"Patient's medications"];
			[exist addObjects:existing];
			[self addSection:exist animated:YES];
		}
	}
	
	// prepare section and init suggestion loader
	INTableSection *section = [INTableSection newWithTitle:@"Suggestions"];
	[self addSection:section animated:YES];
	self.currentMedString = medString;
	self.currentLoader = [INRxNormLoader new];
	
	[currentLoader getSuggestionsFor:medString callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
		if (errorMessage) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to load suggestions"
															message:errorMessage
														   delegate:nil
												  cancelButtonTitle:@"Too Bad"
												  otherButtonTitles:nil];
			[alert show];
		}
		
		// completed, did we get suggestions?
		else if (!userDidCancel) {
			if ([currentLoader.responseObjects count] < 1) {
				[section addObject:@"No suggestions found"];
			}
			else {
				for (NSDictionary *rxDict in currentLoader.responseObjects) {
					[section addObject:[IndivoMedication newWithRxNormDict:rxDict]];
				}
			}
			
			[section updateAnimated:YES];
		}
		
		// stop action indication animation
		nameInputField.leftView = nil;
	}];
}


/**
 *	This method can be used to start off with a given medication object
 */
- (void)loadSuggestionsForMed:(IndivoMedication *)aMed
{
 	[self goToSection:0 animated:YES];
	
	if (aMed) {
		nameInputField.enabled = NO;
		nameInputField.placeholder = aMed.name.abbrev ? aMed.name.abbrev : aMed.name.text;
		NSString *rxcui= aMed.name ? aMed.name.value : aMed.brandName.value;
		
		// prepare section and init suggestion loader
		INTableSection *section = [INTableSection newWithTitle:@"Suggestions"];
		[self addSection:section animated:YES];
		self.currentMedString = nil;
		self.currentLoader = [INRxNormLoader new];
		[currentLoader getRelated:nil forId:rxcui callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
			if (errorMessage) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to load suggestions"
																message:errorMessage
															   delegate:nil
													  cancelButtonTitle:@"Too Bad"
													  otherButtonTitles:nil];
				[alert show];
			}
			
			// completed, did we get suggestions?
			else if (!userDidCancel) {
				if ([currentLoader.responseObjects count] < 1) {
					[section addObject:@"No suggestions found"];
				}
				else {
					for (NSDictionary *rxDict in currentLoader.responseObjects) {
						[section addObject:[IndivoMedication newWithRxNormDict:rxDict]];
					}
				}
				
				[section updateAnimated:YES];
			}
			
			// stop action indication animation
			nameInputField.leftView = nil;
		}];
	}
}


// COPY FROM ABOVE to test barcode scanning
- (void)loadSuggestionsForRxCUI:(NSString *)rxcui
{
 	[self goToSection:0 animated:YES];
	
	if (rxcui) {
		
		// show action
		if (nameInputField) {
			nameInputField.enabled = NO;
			nameInputField.placeholder = @"(Barcode Results)";
			
			UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			nameInputField.enabled = YES;
			nameInputField.leftView = act;
			[act startAnimating];
		}
		
		// prepare section and init suggestion loader
		INTableSection *section = [INTableSection newWithTitle:@"Suggestions"];
		[self addSection:section animated:YES];
		self.currentMedString = nil;
		self.currentLoader = [INRxNormLoader new];
		[currentLoader getRelated:@"SBD" forId:rxcui callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
			if (errorMessage) {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed to load suggestions"
																message:errorMessage
															   delegate:nil
													  cancelButtonTitle:@"Too Bad"
													  otherButtonTitles:nil];
				[alert show];
			}
			
			// completed, did we get suggestions?
			else if (!userDidCancel) {
				if ([currentLoader.responseObjects count] < 1) {
					[section addObject:@"No suggestions found"];
				}
				else {
					for (NSDictionary *rxDict in currentLoader.responseObjects) {
						[section addObject:[IndivoMedication newWithRxNormDict:rxDict]];
					}
				}
				
				[section updateAnimated:YES];
			}
			
			// stop action indication animation
			nameInputField.leftView = nil;
		}];
	}
}



#pragma mark - User Flow
/**
 *	An RX object was selected, go to the next step
 *	The sequence is: IN/MIN -> BN -> SBD
 */
- (void)proceedWith:(NSIndexPath *)indexPath
{
	[nameInputField resignFirstResponder];
	
	if ([sections count] > indexPath.section) {
		INTableSection *current = [sections objectAtIndex:indexPath.section];
		IndivoMedication *startMed = [current objectForRow:indexPath.row];
		if (![startMed isKindOfClass:[IndivoMedication class]]) {
			DLog(@"Did not find a IndivoMedication object, but this: %@", startMed);
			return;
		}
		
		NSString *tty = startMed.dose.unit.abbrev;
		NSString *desired = nil;
		BOOL nowAtDrugEndpoint = NO;
		if ([@"BN" isEqualToString:tty]) {
			nowAtDrugEndpoint = YES;
			desired = @"SBD+DF+IN+PIN+SCDC";
		}
		else if ([@"IN" isEqualToString:tty] || [@"MIN" isEqualToString:tty]) {
			desired = @"BN";
		}
		
		// continue
		if (desired) {
			[current selectRow:indexPath.row collapseAnimated:YES];
			[current showIndicator];
			
			NSString *rxcui= startMed.brandName.value ? startMed.brandName.value : startMed.name.value;
			
			self.currentLoader = [INRxNormLoader loader];
			[currentLoader getRelated:desired forId:rxcui callback:^(BOOL didCancel, NSString *errorString) {
				NSMutableArray *newSections = [NSMutableArray array];
				
				// got some data
				if (!errorString) {
					NSMutableArray *stripFromNames = [NSMutableArray array];
					NSMutableDictionary *scdc = [NSMutableDictionary dictionary];
					NSMutableArray *drugs = [NSMutableArray array];
					
					// look at what we've got
					for (NSDictionary *related in currentLoader.responseObjects) {
						NSString *tty = [related objectForKey:@"tty"];
						NSString *name = [related objectForKey:@"name"];
						NSString *rx = [related objectForKey:@"rxcui"];
						
						// ** we got a DF, dose form, use as section (e.g. "Oral Tablet")
						if ([@"DF" isEqualToString:tty]) {
							if (name) {
								INTableSection *newSection = [INTableSection newWithTitle:name];
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
						
						// ** got a drug (BN or SBD for now), just collect
						else {
							[drugs addObject:[related mutableCopy]];
						}
					}
					
					// no DF-sections found, just add them to one general section
					if ([newSections count] < 1) {
						INTableSection *lone = [INTableSection new];
						[newSections addObject:lone];
					}
					
					// ** revisit collected drugs to apply grouping and name improving
					if ([drugs count] > 0) {
						for (NSMutableDictionary *drug in drugs) {
							NSString *name = [drug objectForKey:@"name"];
							if ([name length] > 0) {
								
								// use SCDC to get the formulation/dose by stripping IN and MIN names
								NSMutableString *myStrength = [NSMutableString string];
								for (NSString *strength in [scdc allKeys]) {
									if (NSNotFound != [name rangeOfString:strength].location) {
										NSString *trimmed = strength;
										for (NSString *strip in stripFromNames) {
											trimmed = [trimmed stringByReplacingOccurrencesOfString:strip withString:@""];
										}
										trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
										if ([trimmed length] > 0) {
											if ([myStrength length] > 0) {
												[myStrength appendFormat:@"/%@", trimmed];
											}
											else {
												[myStrength setString:trimmed];
											}
										}
									}
								}
								if ([myStrength length] > 0) {
									[drug setObject:myStrength forKey:@"formulation"];
								}
								
								// get a medication object
								IndivoMedication *newMed = [IndivoMedication newWithRxNormDict:drug];
								
								// add drug to the matching section (section = DF)
								NSUInteger put = 0;
								for (INTableSection *section in newSections) {
									if (!section.title || NSNotFound != [name rangeOfString:section.title].location) {
										[section addObject:newMed];
										put++;
									}
								}
								if (put < 1) {
									DLog(@"WARNING: Drug %@ not put in any section!!!", drug);
								}
							}
						}
					}
					else {
						DLog(@"Not a single drug found in concepts!");
						INTableSection *newSection = [INTableSection new];
						[newSection addObject:@"No relations found"];
						[newSections addObject:newSection];
					}
				}
				else if (!didCancel) {
					INTableSection *newSection = [INTableSection new];
					[newSection addObject:errorString];
					[newSections addObject:newSection];
				}
				
				// update table
				for (INTableSection *section in newSections) {
					[self addSection:section animated:YES];
				}
				[current hideIndicator];
			}];
		}
		
		// ok, we're happy with the selected drug, move on!
		else {
			[self useDrug:indexPath];
		}
	}
}



- (void)useThisDrug:(INButton *)sender
{
	if ([sender isKindOfClass:[INButton class]]) {
		NSIndexPath *ip = sender.object;
		
		if (INButtonStyleAccept == sender.buttonStyle) {
			[self useDrug:ip];
		}
		else {
			[self proceedWith:ip];
		}
	}
}

/**
 *	If a drug has been chosen, continue to the next fields
 */
- (void)useDrug:(NSIndexPath *)indexPath
{
	if ([sections count] > indexPath.section) {
	INTableSection *section = [sections objectAtIndex:indexPath.section];
	IndivoMedication *useMed = [section objectForRow:indexPath.row];
	if (![useMed isKindOfClass:[IndivoMedication class]]) {
		DLog(@"THIS IS NOT A MEDICATION, CANNOT USE");
		return;
	}
	
	// if we have no medication.name, fetch related IN/MIN first
	if (!useMed.name) {
		self.currentLoader = [INRxNormLoader loader];
		[currentLoader getRelated:@"MIN+IN" forId:useMed.brandName.value callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
			if (!userDidCancel) {
				NSMutableArray *mins = [NSMutableArray arrayWithCapacity:[currentLoader.responseObjects count]];
				NSMutableArray *ins = [NSMutableArray arrayWithCapacity:[currentLoader.responseObjects count]];
				
				// see what we got
				for (NSDictionary *rxDict in currentLoader.responseObjects) {
					if ([@"MIN" isEqualToString:[rxDict objectForKey:@"tty"]]) {
						[mins addObject:rxDict];
					}
					else {
						[ins addObject:rxDict];
					}
				}
				
				// prefer MIN to IN
				NSDictionary *use = nil;
				if ([mins count] > 0) {
					use = [mins objectAtIndex:0];
				}
				else if ([ins count] > 0) {
					if ([ins count] > 1) {
						DLog(@"Got no MIN, but multiple IN: %@", ins);
					}
					use = [ins objectAtIndex:0];
				}
				
				// add and finish off
				if (use) {
					IndivoMedication *refMed = [IndivoMedication newWithRxNormDict:use];
					useMed.name = refMed.name;
				}
				[delegate newMedController:self didSelectMed:useMed];
			}
		}];
	}
	else {
		[delegate newMedController:self didSelectMed:useMed];
	}
	}
	else {
		DLog(@"We don't have a section at index %d!", indexPath.section);
	}
}



#pragma mark - Table Section Updating
/**
 *	Clears all suggestions
 */
- (void)clearSuggestions
{
	// abort loader
	if (currentLoader) {
		[currentLoader cancel];
	}
	
	// clear sections
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
- (void)addSection:(INTableSection *)newSection animated:(BOOL)animated
{
	if (newSection) {
		[self.tableView beginUpdates];
		NSUInteger section = [sections count];
		[sections addObject:newSection];
		[newSection addToTable:self.tableView asSection:section animated:animated];
		[self.tableView endUpdates];
	}
}

/**
 *	Make the given level the active level
 */
- (void)goToSection:(NSUInteger)sectionIdx animated:(BOOL)animated
{
	[self.tableView beginUpdates];
	
	NSInteger i = [sections count] - 1;
	while (i > 0) {						// if we use > 0 we let the first row/section in peace
		INTableSection *existing = [sections objectAtIndex:i];
		
		// remove or expand higher sections
		if (i > sectionIdx) {
			[existing removeAnimated:animated];
			[sections removeLastObject];
		}
		
		// target section, expand
		else if (i == sectionIdx) {
			[existing expandAnimated:animated];
		}
		
		// lower levels
		else {
			
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



#pragma mark - Barcode Scanning
- (void)showCameraScanner:(id)sender
{
	ZBarReaderViewController *reader = [ZBarReaderViewController new];
	reader.readerDelegate = self;
	
	// we only need to look out for UPC-A and EAN-13 codes
	[reader.scanner setSymbology:0 config:ZBAR_CFG_ENABLE to:0];
	[reader.scanner setSymbology:ZBAR_UPCA config:ZBAR_CFG_ENABLE to:1];
	[reader.scanner setSymbology:ZBAR_EAN13 config:ZBAR_CFG_ENABLE to:1];
	
	reader.readerView.zoom = 1.0;
//	reader.scanCrop = CGRectMake(0.f, 0.3f, 1.f, 0.4f);
	
	[self presentModalViewController:reader animated:YES];
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info
{
	id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
	for (ZBarSymbol *rslt in results) {
		
		// loop results
		if ([rslt isKindOfClass:[ZBarSymbol class]]) {
			NSMutableString *code = [[rslt.data substringToIndex:[rslt.data length] - 1] mutableCopy];		// chop off control digit
			
			// UPC-A codes start with a "3"
			if ([@"UPC-A" isEqualToString:rslt.typeName]) {
				[code replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
			}
			
			// EAN-13 codes start with "03"
			else if ([@"EAN-13" isEqualToString:rslt.typeName]) {
				[code replaceCharactersInRange:NSMakeRange(0, 2) withString:@""];
			}
			
			if ([code length] < 10) {
				DLog(@"This cannot be right: \"%@\"", code);
			}
			
			// got the ten-digit code, which could be in these formats: 4-4-2, 5-3-2, or 5-4-1 (and the normalized 11-digit version)
			else {
				NSMutableArray *variants = [NSMutableArray arrayWithCapacity:4];
				[variants addObject:[NSString stringWithFormat:@"0%@", code]];
				
				NSUInteger i = 0;
				for (; i < 3; i++) {
					NSMutableString *variant = [code mutableCopy];
					if (0 == i) {
						[variant insertString:@"-" atIndex:8];
						[variant insertString:@"-" atIndex:4];
					}
					else if (1 == i) {
						[variant insertString:@"-" atIndex:8];
						[variant insertString:@"-" atIndex:5];
					}
					else {
						[variant insertString:@"-" atIndex:9];
						[variant insertString:@"-" atIndex:5];
					}
					[variants addObject:variant];
				}
				
				// try to get the rxcui for the code
				NSString *queryURLString = [NSString stringWithFormat:@"http://10.17.20.127:8002/ndc/%@", [variants objectAtIndex:0]];
				INURLLoader *loader = [INURLLoader loaderWithURL:[NSURL URLWithString:queryURLString]];
				[loader getWithCallback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
					if (errorMessage) {
						DLog(@"Error: %@", errorMessage);
					}
					else if (!userDidCancel) {
						[self imagePickerControllerDidCancel:picker];
						[self loadSuggestionsForRxCUI:loader.responseString];
					}
				}];
			}
		}
		else {
			DLog(@"No ZBarSymbol, got: %@", rslt);
		}
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
	[self dismissModalViewControllerAnimated:YES];
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
	
	// add the scan button
	UIBarButtonItem *cameraButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(showCameraScanner:)];
	self.navigationItem.leftBarButtonItem = cameraButton;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
	// start with a given rxcui or string?
	if (!self.initialMed && [delegate respondsToSelector:@selector(initialMedForNewMedController:)]) {
		self.initialMed = [delegate initialMedForNewMedController:self];
		self.initialMedString = nil;
	}
	if (!self.initialMed && !self.initialMedString && [delegate respondsToSelector:@selector(initialMedStringForNewMedController:)]) {
		self.initialMedString = [delegate initialMedStringForNewMedController:self];
	}
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



#pragma mark - KVC
- (UITextField *)nameInputField
{
	if (!nameInputField) {
		self.nameInputField = [[UITextField alloc] initWithFrame:CGRectMake(10.f, 10.f, 300.f, 27.f)];
		nameInputField.tag = 99;
		nameInputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		nameInputField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		nameInputField.enablesReturnKeyAutomatically = NO;
		nameInputField.returnKeyType = UIReturnKeyDone;
		nameInputField.clearButtonMode = UITextFieldViewModeAlways;
		nameInputField.autocorrectionType = UITextAutocorrectionTypeNo;
		nameInputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		nameInputField.placeholder = @"Medication Name";
		nameInputField.font = [UIFont systemFontOfSize:17.f];
		nameInputField.leftViewMode = UITextFieldViewModeAlways;
		nameInputField.delegate = self;
	}
	return nameInputField;
}



#pragma mark - Utilities
/// @todo Currently not used, maybe it's still useful?
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
