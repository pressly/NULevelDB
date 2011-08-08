// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestCompany.m instead.

#import "_NULDBTestCompany.h"

@implementation NULDBTestCompanyID
@end

@implementation _NULDBTestCompany

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Company" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Company";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Company" inManagedObjectContext:moc_];
}

- (NULDBTestCompanyID*)objectID {
	return (NULDBTestCompanyID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic name;






@dynamic primaryAddressID;






@dynamic addresses;

	
- (NSMutableSet*)addressesSet {
	[self willAccessValueForKey:@"addresses"];
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"addresses"];
	[self didAccessValueForKey:@"addresses"];
	return result;
}
	

@dynamic roles;

	
- (NSMutableSet*)rolesSet {
	[self willAccessValueForKey:@"roles"];
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"roles"];
	[self didAccessValueForKey:@"roles"];
	return result;
}
	

@dynamic workers;

	
- (NSMutableSet*)workersSet {
	[self willAccessValueForKey:@"workers"];
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"workers"];
	[self didAccessValueForKey:@"workers"];
	return result;
}
	



@dynamic mainAddress;

@dynamic secondaryAddresses;



@end
