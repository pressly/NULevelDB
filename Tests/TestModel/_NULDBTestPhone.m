// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestPhone.m instead.

#import "_NULDBTestPhone.h"

@implementation NULDBTestPhoneID
@end

@implementation _NULDBTestPhone

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Phone" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Phone";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Phone" inManagedObjectContext:moc_];
}

- (NULDBTestPhoneID*)objectID {
	return (NULDBTestPhoneID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"areaCodeValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"areaCode"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"exchangeValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"exchange"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"lineValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"line"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic areaCode;



- (short)areaCodeValue {
	NSNumber *result = [self areaCode];
	return [result shortValue];
}

- (void)setAreaCodeValue:(short)value_ {
	[self setAreaCode:[NSNumber numberWithShort:value_]];
}

- (short)primitiveAreaCodeValue {
	NSNumber *result = [self primitiveAreaCode];
	return [result shortValue];
}

- (void)setPrimitiveAreaCodeValue:(short)value_ {
	[self setPrimitiveAreaCode:[NSNumber numberWithShort:value_]];
}





@dynamic exchange;



- (short)exchangeValue {
	NSNumber *result = [self exchange];
	return [result shortValue];
}

- (void)setExchangeValue:(short)value_ {
	[self setExchange:[NSNumber numberWithShort:value_]];
}

- (short)primitiveExchangeValue {
	NSNumber *result = [self primitiveExchange];
	return [result shortValue];
}

- (void)setPrimitiveExchangeValue:(short)value_ {
	[self setPrimitiveExchange:[NSNumber numberWithShort:value_]];
}





@dynamic line;



- (short)lineValue {
	NSNumber *result = [self line];
	return [result shortValue];
}

- (void)setLineValue:(short)value_ {
	[self setLine:[NSNumber numberWithShort:value_]];
}

- (short)primitiveLineValue {
	NSNumber *result = [self primitiveLine];
	return [result shortValue];
}

- (void)setPrimitiveLineValue:(short)value_ {
	[self setPrimitiveLine:[NSNumber numberWithShort:value_]];
}





@dynamic person;

	





@end
