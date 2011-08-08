// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestPerson.m instead.

#import "_NULDBTestPerson.h"

@implementation NULDBTestPersonID
@end

@implementation _NULDBTestPerson

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Person";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Person" inManagedObjectContext:moc_];
}

- (NULDBTestPersonID*)objectID {
	return (NULDBTestPersonID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic firstName;






@dynamic lastName;






@dynamic address;

	

@dynamic company;

	

@dynamic phone;

	

@dynamic role;

	





@end
