//
//  IndivoMedication+RxNorm.m
//  MedReconcile
//
//  Created by Pascal Pfiffner on 1/19/12.
//  Copyright (c) 2012 Children's Hospital Boston. All rights reserved.
//

#import "IndivoMedication+RxNorm.h"

@implementation IndivoMedication (RxNorm)


/**
 *  Instantiates an object from data given in the dictionary, which should contain RxNorm information like tty and rxcui
 */
+ (id)newWithRxNormDict:(NSDictionary *)aDict
{
	NSString *name = [aDict objectForKey:@"name"];
	if ([name length] > 0) {
		IndivoMedication *newMed = [IndivoMedication new];
//		NSString *tty = [aDict objectForKey:@"tty"];
		NSString *rxcui = [aDict objectForKey:@"rxcui"];
		
		// try to find a display name. We're looking for the brand name which RxNorm supplies in [square brackets]
		NSRegularExpression *nameExp = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]" options:0 error:nil];
		NSTextCheckingResult *match = [nameExp firstMatchInString:name options:0 range:NSMakeRange(0, [name length])];
		NSRange matchRange = [match rangeAtIndex:1];
		DLog(@"match range: %@", NSStringFromRange(matchRange));
		
		// the drug allows to fill the prescription name
		newMed.drugName = [INCodedValue new];
		newMed.drugName.title = name;
		if ([rxcui length] > 0) {
			newMed.drugName.system = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
			newMed.drugName.identifier = rxcui;
		}
		
		/// @todo NEW SCHEMA TESTING -- quantity is substitute for "formulation"
		newMed.quantity = [INUnitValue newWithNodeName:@"quantity"];
		newMed.quantity.value = [NSDecimalNumber one];
//		newMed.quantity.unit = @"http://indivo.org/codes/units#";
		
		//DLog(@"%@ -> %@", aDict, newMed);
		return newMed;
	}
	
	DLog(@"The RxNorm dictionary did not contain a name");
	return nil;
}


/**
 *  Creates a simple dictionary with "name", "rxcui" and "tty" nodes.
 */
- (NSDictionary *)rxNormDict
{
	NSString *name = self.drugName.title;
	NSString *rxcui = self.drugName.identifier;
	NSString *tty = self.quantity.unit;								///< COMPLETE HACK!!!
	
	return [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", rxcui, @"rxcui", tty, @"tty", nil];
}


- (BOOL)matchesName:(NSString *)aName
{
	if ([self.drugName.title rangeOfString:aName].location > -1 || [self.drugName.identifier rangeOfString:aName].location > -1) {
		return YES;
	}
	return NO;
}


@end
