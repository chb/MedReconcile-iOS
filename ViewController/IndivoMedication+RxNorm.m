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
 *	Instantiates an object from data given in the dictionary, which should contain RxNorm information like tty and rxcui
 */
+ (id)newWithRxNormDict:(NSDictionary *)aDict
{
	NSString *name = [aDict objectForKey:@"name"];
	if ([name length] > 0) {
		IndivoMedication *newMed = [IndivoMedication new];
		NSString *tty = [aDict objectForKey:@"tty"];
		NSString *rxcui = [aDict objectForKey:@"rxcui"];
		
		// try to find a display name. We're looking for the brand name which RxNorm supplies in [square brackets]
		NSString *brandName = name;
		NSRegularExpression *nameExp = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]" options:0 error:nil];
		NSTextCheckingResult *match = [nameExp firstMatchInString:name options:0 range:NSMakeRange(0, [name length])];
		NSRange matchRange = [match rangeAtIndex:1];
		if (NSNotFound != matchRange.location && matchRange.length > 0) {
			brandName = [name substringWithRange:matchRange];
		}
		
		// add formulation to the brandName if we have it
		if ([aDict objectForKey:@"formulation"]) {
			brandName = [brandName stringByAppendingFormat:@" %@", [aDict objectForKey:@"formulation"]];
		}
		
		// the drug allows to fill the prescription name
		if ([@"SBD" isEqualToString:tty] || [@"BN" isEqualToString:tty]) {
			newMed.brandName = [INCodedValue new];
			newMed.brandName.text = name;
			newMed.brandName.abbrev = brandName;
			if ([rxcui length] > 0) {
				newMed.brandName.type = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
				newMed.brandName.value = rxcui;
			}
		}
		
		// only fill the medication name
		else {
			newMed.name = [INCodedValue new];
			newMed.name.text = name;
			newMed.name.abbrev = brandName;
			if ([rxcui length] > 0) {
				newMed.name.type = @"http://rxnav.nlm.nih.gov/REST/rxcui/";
				newMed.name.value = rxcui;
			}
		}
		
		/// @todo NEW SCHEMA TESTING -- dose is substitute for "formulation"
		newMed.dose = [INUnitValue newWithNodeName:@"dose"];
		newMed.dose.value = [NSDecimalNumber one];							// ignored but needed for validation
		newMed.dose.unit.type = @"http://indivo.org/codes/units#";			// ignored but needed for validation
		newMed.dose.unit.abbrev = tty;										// hacked in here to have access to the type (!)
		newMed.dose.unit.value = [aDict objectForKey:@"formulation"];
		
		//DLog(@"%@ -> %@", aDict, newMed);
		return newMed;
	}
	return nil;
}


/**
 *	Creates a simple dictionary with "name", "rxcui" and "tty" nodes.
 */
- (NSDictionary *)rxNormDict
{
	NSString *name = self.brandName ? self.brandName.text : self.name.text;
	NSString *rxcui = self.brandName ? self.brandName.value : self.name.value;
	NSString *tty = self.dose.unit.abbrev;								///< COMPLETE HACK!!!
	
	return [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", rxcui, @"rxcui", tty, @"tty", nil];
}


- (BOOL)matchesName:(NSString *)aName
{
	if ([self.name.text rangeOfString:aName].location > -1
		|| [self.name.abbrev rangeOfString:aName].location > -1
		|| [self.brandName.text rangeOfString:aName].location > -1
		|| [self.brandName.abbrev rangeOfString:aName].location > -1) {
		return YES;
	}
	return NO;
}


@end
