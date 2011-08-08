// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestRole.m instead.

#import "_NULDBTestRole.h"

@implementation NULDBTestRoleID
@end

@implementation _NULDBTestRole

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Role" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Role";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Role" inManagedObjectContext:moc_];
}

- (NULDBTestRoleID*)objectID {
	return (NULDBTestRoleID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic name;






@dynamic company;

	

@dynamic manager;

	





@end
