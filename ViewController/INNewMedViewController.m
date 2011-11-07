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


@interface INNewMedViewController ()

@property (nonatomic, strong) NSMutableArray *suggestions;							///< An array to hold our suggestions for drugs matching the current name
@property (nonatomic, copy) NSString *currentMedString;								///< The string for which suggestions are being loaded
@property (nonatomic, assign) NSInteger showLoadingSuggestionsIndicator;			///< If >0 shows an indicator that we are loading suggestions
@property (nonatomic, strong) UIView *loadingView;

- (void)clearSuggestions;
- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString;

@end


@implementation INNewMedViewController

@synthesize suggestions, currentMedString;
@synthesize showLoadingSuggestionsIndicator, loadingView;


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



#pragma mark - Loading Suggestions
/**
 *	Begin to start medication suggestions from ...
 */
- (void)loadSuggestionsFor:(NSString *)medString
{
	self.currentMedString = medString;
	showLoadingSuggestionsIndicator++;
	NSIndexSet *suggSet = [NSIndexSet indexSetWithIndex:1];
	[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationNone];
	
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
			[suggestions removeAllObjects];
			if (!suggestions) {
				self.suggestions = [NSMutableArray arrayWithCapacity:20];
			}
			[suggestions addObject:medString];
			
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
								NSString *urlString = [NSString stringWithFormat:@"%@/rxcui/%@", urlBase, rxcui];
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
						INURLFetcher *fetcher = [INURLFetcher new];
						[fetcher getURLs:urls callback:^(BOOL userDidCancel, NSString *__autoreleasing errorMessage) {
							[self fetcher:fetcher didLoadSuggestionsFor:medString];
						}];
					}
				}
			}
		}
		
		[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationFade];
	}];
}

- (void)fetcher:(INURLFetcher *)aFetcher didLoadSuggestionsFor:(NSString *)medString
{
	showLoadingSuggestionsIndicator--;
	
	if ([currentMedString isEqualToString:medString]) {
		if ([aFetcher.successfulLoads count] > 0) {
			
			// add suggestions and reload the table
			for (INURLLoader *loader in aFetcher.successfulLoads) {
				
				// parse XML
				NSError *error = nil;
				INXMLNode *node = [INXMLParser parseXML:loader.responseString error:&error];
				if (!node) {
					DLog(@"Error Parsing: %@", [error localizedDescription]);
				}
				else {
					NSString *name = [[[node childNamed:@"idGroup"] childNamed:@"name"] text];
					if (name) {
						[suggestions addObject:name];
					}
				}
			}
			
			// reload table view
			NSIndexSet *suggSet = [NSIndexSet indexSetWithIndex:1];
			[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationNone];
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
 *	Clears current suggestions
 */
- (void)clearSuggestions
{
	showLoadingSuggestionsIndicator = 0;
	[suggestions removeAllObjects];
	
	NSIndexSet *suggSet = [NSIndexSet indexSetWithIndex:1];
	[self.tableView reloadSections:suggSet withRowAnimation:UITableViewRowAnimationFade];
}



#pragma mark - Table View Data Source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	if (0 == section) {
		return 1;
	}
	return [suggestions count];
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
	return (1 == section && [suggestions count] > 0) ? @"Suggestions" : nil;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (1 != section) {
		return 0.f;
	}
	return 28.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (1 == section && (showLoadingSuggestionsIndicator > 0)) {
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
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident];
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
	else if (1 == indexPath.section) {
		cell.textLabel.text = [suggestions objectAtIndex:indexPath.row];
	}
	
	return cell;
}



#pragma mark - Table View Delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	/// @todo the suggestions section will have higher rows
	return tableView.rowHeight;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	
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

- (UIView *)loadingView
{
	if (!loadingView) {
		self.loadingView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, 320.f, 28.f)];
		loadingView.opaque = NO;
		loadingView.backgroundColor = [UIColor clearColor];
		loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		CGRect actFrame = activity.frame;
		actFrame.origin = CGPointMake(20.f, 4.f);
		activity.frame = actFrame;
		[loadingView addSubview:activity];
		[activity startAnimating];
		
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(50.f, 0.f, 280.f, 28.f)];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		label.opaque = NO;
		label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont boldSystemFontOfSize:15.f];
		label.textColor = [UIColor darkGrayColor];
		label.shadowColor = [UIColor colorWithWhite:1.f alpha:0.8f];
		label.shadowOffset = CGSizeMake(0.f, 1.f);
		label.text = @"Loading Suggestions...";
		[loadingView addSubview:label];
	}
	return loadingView;
}


@end
