// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestAddress.m instead.

#import "_NULDBTestAddress.h"

@implementation NULDBTestAddressID
@end

@implementation _NULDBTestAddress

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Address" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Address";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Address" inManagedObjectContext:moc_];
}

- (NULDBTestAddressID*)objectID {
	return (NULDBTestAddressID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic city;






@dynamic postalCode;






@dynamic state;






@dynamic street;






@dynamic company;

	

@dynamic person;

	





@end
