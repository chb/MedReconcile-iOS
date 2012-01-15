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
#import "INButton.h"

#import "IndivoServer.h"
#import "INXMLParser.h"
#import "INXMLNode.h"
#import "IndivoMedication.h"
#import "NSArray+NilProtection.h"


@interface INNewMedViewController ()

@property (nonatomic, strong) NSMutableArray *sections;								///< An array full of INTableSection objects
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
@synthesize initialMedString, currentMedString, currentLoader;
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
			[cell.contentView addSubview:self.nameInputField];
			if (initialMedString) {
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
	NSDictionary *drug = [section objectForRow:indexPath.row];
	if ([drug isKindOfClass:[NSDictionary class]]) {
		cell.textLabel.text = drug ? [drug objectForKey:@"name"] : @"Unknown";
		// cell.detailTextLabel.text = [drug objectForKey:@"tty"];
		
		BOOL canUseDrug = ([@"SBD" isEqualToString:[drug objectForKey:@"tty"]] || drug == [section selectedObject]);
		DLog(@"%@: %d", cell.textLabel.text, canUseDrug);
		INButtonStyle style = canUseDrug ? INButtonStyleAccept : INButtonStyleMain;
		INButton *use = [INButton buttonWithStyle:style];
		use.frame = CGRectMake(0.f, 0.f, 60.f, 31.f);
		use.object = indexPath;
		[use addTarget:self action:@selector(useThisDrug:) forControlEvents:UIControlEventTouchUpInside];
		[use setTitle:(canUseDrug ? @"Use" : @"More") forState:UIControlStateNormal];
		cell.accessoryView = use;
	}
	
	//cell.accessoryView = [section accessoryViewForRow:indexPath.row];		// returns the indicator view for the active row
	
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
	
	INTableSection *section = [INTableSection new];
	[self addSection:section animated:YES];
	
	// show action
	if (nameInputField) {
		UIActivityIndicatorView *act = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		nameInputField.leftView = act;
		[act startAnimating];
	}
	
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
		
		// got suggestions
		else if (!userDidCancel) {
			NSArray *resArray = currentLoader.responseObjects;
			if (!resArray || [resArray isKindOfClass:[NSArray class]]) {
				if ([resArray count] < 1) {
					NSDictionary *fakeDrug = [NSDictionary dictionaryWithObject:@"No suggestions found" forKey:@"name"];
					[section addObject:fakeDrug];
				}
				else {
					[section addObjects:currentLoader.responseObjects];
				}
			}
			else {
				DLog(@"ERROR, expected an array, got: %@", currentLoader.responseObjects);
			}
			[section updateAnimated:YES];
		}
		
		// stop action indication animation
		nameInputField.leftView = nil;
	}];
}



#pragma mark - User Flow
/**
 *	An RX object was selected, go to the next step
 *	The sequence is: IN -> BN -> SBD
 */
- (void)proceedWith:(NSIndexPath *)indexPath
{
	[nameInputField resignFirstResponder];
	
	INTableSection *current = [sections objectAtIndex:indexPath.section];
	NSDictionary *drugDict = [current objectForRow:indexPath.row];
	
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
		[current selectRow:indexPath.row collapseAnimated:YES];
		[current showIndicator];
		
		self.currentLoader = [INRxNormLoader loader];
		[currentLoader getRelated:desired forId:rxcui callback:^(BOOL didCancel, NSString *errorString) {
			NSMutableArray *newSections = [NSMutableArray array];
			
			// got some data
			if (!errorString) {
				NSMutableArray *stripFromNames = [NSMutableArray array];
				NSMutableDictionary *scdc = [NSMutableDictionary dictionary];
				NSMutableArray *drugs = [NSMutableArray array];
				
				// look at what we've got
				for (NSString *tty in [currentLoader.responseObjects allKeys]) {
					NSArray *relatedArr = [currentLoader.responseObjects objectForKey:tty];
					for (NSDictionary *related in relatedArr) {
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
						
						// ** got a drug (BN or SBD for now)
						else {
							NSMutableDictionary *drug = [NSMutableDictionary dictionaryWithDictionary:related];
							[drug setObject:tty forKey:@"tty"];
							[drugs addObject:drug];
						}
					}
				}
				
				// no DF-sections found, just add them to one general section
				if ([newSections count] < 1) {
					INTableSection *lone = [INTableSection new];
					[newSections addObject:lone];
				}
				
				// revisit drugs to apply grouping and name improving
				if ([drugs count] > 0) {
					
					// ** loop all drugs
					for (NSMutableDictionary *drug in drugs) {
						NSString *name = [drug objectForKey:@"name"];
						if ([name length] > 0) {
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
							NSRegularExpression *whitespace = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
							name = [whitespace stringByReplacingMatchesInString:name options:0 range:NSMakeRange(0, [name length]) withTemplate:@" "];
							name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
							[drug setObject:name forKey:@"name"];
						}
					}
				}
				else {
					DLog(@"Not a single drug found in concepts!");
					NSDictionary *fakeDrug = [NSDictionary dictionaryWithObject:@"No relations found" forKey:@"name"];
					INTableSection *newSection = [INTableSection new];
					[newSection addObject:fakeDrug];
					[newSections addObject:newSection];
				}
			}
			else if (!didCancel) {
				NSDictionary *fakeDrug = [NSDictionary dictionaryWithObject:errorString forKey:@"name"];
				INTableSection *newSection = [INTableSection new];
				[newSection addObject:fakeDrug];
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
	INTableSection *section = [sections objectAtIndex:indexPath.section];
	NSDictionary *drugDict = [section objectForRow:indexPath.row];
	
	// create medication document
	IndivoMedication *med = [IndivoMedication newWithRecord:APP_DELEGATE.indivo.activeRecord];
	if (!med) {
		DLog(@"Did not get a medication document!");
	}
	
	// name
	NSDictionary *nonbranded = [drugDict objectForKey:@"nonbranded"];
	med.name = [INCodedValue newWithNodeName:@"name"];
	if (nonbranded) {
		if ([nonbranded objectForKey:@"rxcui"]) {
			med.name.type = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
			med.name.value = [nonbranded objectForKey:@"rxcui"];
		}
		else {
			DLog(@"NO RX IDENTIFIER FOR NONBRANDED");
		}
		med.name.text = [nonbranded objectForKey:@"name"];
	}
	else {
		med.name.text = @"<Fetch generic>";
	}
	
	// branded name
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
	
	// date started and stopped
	med.prescription = [IndivoPrescription new];
	med.dateStarted = [INDate dateWithDate:[NSDate date]];		// to make the current scheme validate
	med.prescription.on = [INDate dateWithDate:[NSDate date]];
	med.prescription.stopOn = [INDate dateWithDate:[[NSDate date] dateByAddingTimeInterval:14*24*3600]];
	med.prescription.dispenseAsWritten = [INBool newNo];
	
	// inform delegate
	NSLog(@"\n%@\n", [med xml]);
	[delegate newMedController:self didSelectMed:med];
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
	
	// start with a given string?
	if ([delegate respondsToSelector:@selector(initialMedStringForNewMedController:)]) {
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
