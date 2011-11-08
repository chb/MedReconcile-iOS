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
@property (nonatomic, strong) NSMutableArray *suggested;							///< A 2d array with the selected suggestion per level
@property (nonatomic, assign) NSUInteger suggestionLevel;							///< The active level
@property (nonatomic, copy) NSString *currentMedString;								///< The string for which suggestions are being loaded

@property (nonatomic, assign) NSInteger showLoadingSuggestionsIndicator;			///< If >0 shows an indicator that we are loading suggestions
@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) UILabel *loadingTextLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingActivity;

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString;
- (void)clearSuggestions;
- (void)proceedWith:(INXMLNode *)aNode onLevel:(NSUInteger)onLevel;

- (void)updateLoadingLabel;

@end


@implementation INNewMedViewController

@synthesize suggestions, suggested, suggestionLevel, currentMedString;
@synthesize showLoadingSuggestionsIndicator, loadingView, loadingTextLabel, loadingActivity;


- (id)init
{
	return [self initWithNibName:nil bundle:nil];
}

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)aBundle
{
    if ((self = [super initWithNibName:nibName bundle:aBundle])) {
		self.title = @"New Medication";
    }
    return self;
}



#pragma mark - Table View Data Source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return [suggestions count] + 1;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	if ((suggestionLevel + 1) == section) {
		return [[suggestions objectOrNilAtIndex:suggestionLevel] count];
	}
	return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return ((suggestionLevel + 1) == section) ? 28.f : 0.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	NSArray *levelSuggestions = [suggestions objectOrNilAtIndex:suggestionLevel];
	if ((suggestionLevel + 1) == section && ([levelSuggestions count] > 0)) {
		return self.loadingView;
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
		if ((suggestionLevel + 1) == indexPath.section) {
			NSArray *level = [suggestions objectOrNilAtIndex:(indexPath.section - 1)];
			drug = [level objectOrNilAtIndex:indexPath.row];
		}
		else {
			drug = [suggested objectOrNilAtIndex:indexPath.section];
		}
		
		cell.textLabel.text = drug ? [[drug childNamed:@"name"] text] : @"Unknown";
		cell.detailTextLabel.text = drug ? [[drug childNamed:@"tty"] text] : nil;
	}
	
	return cell;
}



#pragma mark - Table View Delegate
/*- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
}	//	*/



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section > 0) {
		NSArray *level = [suggestions objectOrNilAtIndex:(indexPath.section - 1)];
		
		// get the tapped node and set it selected
		INXMLNode *tappedObject = [level objectOrNilAtIndex:indexPath.row];
		if (!suggested) {
			self.suggested = [NSMutableArray array];
		}
		else {
			while ([suggested count] > suggestionLevel) {
				[suggested removeLastObject];
			}
		}
		[suggested addObject:tappedObject];
		
		// adjust level
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		NSIndexSet *sectionSet = [NSIndexSet indexSetWithIndex:indexPath.section];
		[self.tableView reloadSections:sectionSet withRowAnimation:UITableViewRowAnimationFade];
		
		// proceed
		[self proceedWith:tappedObject onLevel:(indexPath.section - 1)];
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
		[self performSelector:@selector(loadSuggestionsFor:) withObject:current afterDelay:0.4];
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
	self.currentMedString = medString;
	showLoadingSuggestionsIndicator = MAX(1, showLoadingSuggestionsIndicator + 1);
	[self updateLoadingLabel];
	NSIndexSet *suggSet = [NSIndexSet indexSetWithIndex:1];
//	[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationNone];
	
	// start loading suggestions
	//	NSString *apiKey = @"HELUUSPMYB";
	//	NSString *urlBase = [NSString stringWithFormat:@"http://pillbox.nlm.nih.gov/PHP/pillboxAPIService.php?key=%@", apiKey];
	NSString *urlBase = @"http://rxnav.nlm.nih.gov/REST";
	NSString *urlString = [NSString stringWithFormat:@"%@/approxMatch/%@", urlBase, [medString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSURL *url = [NSURL URLWithString:urlString];
	DLog(@"Going to load from: %@", url);
	
	INURLLoader *loader = [[INURLLoader alloc] initWithURL:url];
	[loader getWithCallback:^(BOOL didCancel, NSString *errorString) {
		showLoadingSuggestionsIndicator--;
		
		// failed
		if (errorString) {
			DLog(@"Error Loading: %@", errorString);
		}
		
		// got some suggestions!
		else {
			if (!suggestions) {
				self.suggestions = [NSMutableArray arrayWithCapacity:3];
			}
			NSMutableArray *sugg = [suggestions objectOrNilAtIndex:0];
			if (!sugg) {
				sugg = [NSMutableArray array];
				[suggestions insertObject:sugg atIndex:0];
			}
			[sugg removeAllObjects];
			
			INXMLNode *name = [INXMLNode nodeWithName:@"name" attributes:nil];
			name.text = medString;
			INXMLNode *myDrug = [INXMLNode nodeWithName:@"properties" attributes:nil];
			[myDrug addChild:name];
			[sugg addObject:myDrug];
			
			// parse
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
						[self updateLoadingLabel];
						
						INURLFetcher *fetcher = [INURLFetcher new];
						[fetcher getURLs:urls callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
							[self fetcher:fetcher didLoadSuggestionsFor:medString];
						}];
					}
				}
			}
		}
		
//		[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationNone];
	}];
}

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString
{
	showLoadingSuggestionsIndicator--;
	[self updateLoadingLabel];
	
	if ([currentMedString isEqualToString:medString]) {
		if ([aFetcher.successfulLoads count] > 0) {
			NSMutableArray *sugg = [suggestions objectOrNilAtIndex:0];
			
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
						DLog(@"GOT: %@  (%@) [%@]", tty, [[drug childNamed:@"name"] text], [[drug childNamed:@"rxcui"] text]);
						if (tty && ([tty isEqualToString:@"IN"] || [tty isEqualToString:@"BN"])) {
							[sugg addObject:drug];
						}
					}
				}
			}
			
			// reload table view
//			NSIndexSet *suggSet = [NSIndexSet indexSetWithIndex:1];
//			[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationNone];
			[self.tableView reloadData];
		}
		else {
			DLog(@"ALL loaders failed to load!");
		}
	}
	else {
		DLog(@"Received suggestions for \"%@\", but we have moved on to \"%@\", discarding", medString, currentMedString);
	}
}

/**
 *	Clears all suggestions
 */
- (void)clearSuggestions
{
	showLoadingSuggestionsIndicator = 0;
	[self updateLoadingLabel];
	[suggestions removeAllObjects];
	
	NSIndexSet *suggSet = [NSIndexSet indexSetWithIndex:1];
	[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationFade];
}


/**
 *	An RX object was selected, go to the next step
 *	The sequence is: IN -> BN -> SBD
 */
- (void)proceedWith:(INXMLNode *)aNode onLevel:(NSUInteger)onLevel
{
	NSString *tty = [[aNode childNamed:@"tty"] text];
	NSString *rxcui = [[aNode childNamed:@"rxcui"] text];
	
	NSString *urlBase = @"http://rxnav.nlm.nih.gov/REST";
	NSString *urlString = nil;
	if ([@"BN" isEqualToString:tty]) {
		urlString = [NSString stringWithFormat:@"%@/rxcui/%@/related?tty=SBD", urlBase, rxcui];
	}
	else if ([@"IN" isEqualToString:tty]) {
		urlString = [NSString stringWithFormat:@"%@/rxcui/%@/related?tty=BN", urlBase, rxcui];
	}
	
	// continue
	if (urlString) {
		suggestionLevel = onLevel + 1;
		NSURL *url = [NSURL URLWithString:urlString];
		
		showLoadingSuggestionsIndicator = MAX(1, showLoadingSuggestionsIndicator + 1);
		[self updateLoadingLabel];
//		NSIndexSet *mySet = [NSIndexSet indexSetWithIndex:(suggestionLevel + 1)];
//		[self.tableView reloadSections:mySet withRowAnimation:UITableViewRowAnimationFade];
		
		DLog(@"Going to load from: %@", url);
		INURLLoader *loader = [[INURLLoader alloc] initWithURL:url];
		[loader getWithCallback:^(BOOL didCancel, NSString *errorString) {
			showLoadingSuggestionsIndicator--;
			[self updateLoadingLabel];
			
			// failed
			if (errorString) {
				DLog(@"Error Loading: %@", errorString);
			}
			
			// got some suggestions!
			else {
				NSMutableArray *sugg = [suggestions objectOrNilAtIndex:suggestionLevel];
				if (!sugg) {
					sugg = [NSMutableArray array];
					[suggestions insertObject:sugg atIndex:suggestionLevel];
				}
				[sugg removeAllObjects];
				
				// parse
				NSError *error = nil;
				INXMLNode *body = [INXMLParser parseXML:loader.responseString error:&error];
				
				// parsed successfully, drill down
				if (body) {
					INXMLNode *list = [[body childNamed:@"relatedGroup"] childNamed:@"conceptGroup"];
					if (list) {
						NSArray *suggNodes = [list childrenNamed:@"conceptProperties"];
						
						// ok, we're down to the relation nodes
						if ([suggNodes count] > 0) {
							[sugg addObjectsFromArray:suggNodes];
						}
						else {
							DLog(@"No conceptProperties children found in %@", list);
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
			
			[self.tableView reloadData];
		}];
	}
	
	// at last step
	else {
		DLog(@"THE END, go get: http://rxnav.nlm.nih.gov/REST/rxcui/%@/ndcs", rxcui);
	}
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



#pragma mark - Loading Indicator
/**
 *	Starts and stops the spinner and adjusts the text
 */
- (void)updateLoadingLabel
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
- (UIView *)loadingView
{
	if (!loadingView) {
		self.loadingView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, 320.f, 28.f)];
		loadingView.opaque = NO;
		loadingView.backgroundColor = [UIColor clearColor];
		loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20.f, 0.f, 280.f, 28.f)];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		label.opaque = NO;
		label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont boldSystemFontOfSize:15.f];
		label.textColor = [UIColor darkGrayColor];
		label.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		label.shadowOffset = CGSizeMake(0.f, 1.f);
		label.text = @"Suggestions";
		[loadingView addSubview:label];
		self.loadingTextLabel = label;
		
		CGRect loadingFrame = loadingView.frame;
		self.loadingActivity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		CGRect actFrame = loadingActivity.frame;
		actFrame.origin = CGPointMake(loadingFrame.size.width - 20.f - actFrame.size.width, 4.f);
		loadingActivity.frame = actFrame;
		loadingActivity.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[loadingView addSubview:loadingActivity];
	}
	return loadingView;
}


@end
