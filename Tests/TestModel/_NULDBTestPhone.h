// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestPhone.h instead.

#import <CoreData/CoreData.h>


@class NULDBTestPerson;





@interface NULDBTestPhoneID : NSManagedObjectID {}
@end

@interface _NULDBTestPhone : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (NULDBTestPhoneID*)objectID;




@property (nonatomic, retain) NSNumber *areaCode;


@property short areaCodeValue;
- (short)areaCodeValue;
- (void)setAreaCodeValue:(short)value_;

//- (BOOL)validateAreaCode:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSNumber *exchange;


@property short exchangeValue;
- (short)exchangeValue;
- (void)setExchangeValue:(short)value_;

//- (BOOL)validateExchange:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSNumber *line;


@property short lineValue;
- (short)lineValue;
- (void)setLineValue:(short)value_;

//- (BOOL)validateLine:(id*)value_ error:(NSError**)error_;





@property (nonatomic, retain) NULDBTestPerson* person;

//- (BOOL)validatePerson:(id*)value_ error:(NSError**)error_;




@end

@interface _NULDBTestPhone (CoreDataGeneratedAccessors)

@end

@interface _NULDBTestPhone (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveAreaCode;
- (void)setPrimitiveAreaCode:(NSNumber*)value;

- (short)primitiveAreaCodeValue;
- (void)setPrimitiveAreaCodeValue:(short)value_;




- (NSNumber*)primitiveExchange;
- (void)setPrimitiveExchange:(NSNumber*)value;

- (short)primitiveExchangeValue;
- (void)setPrimitiveExchangeValue:(short)value_;




- (NSNumber*)primitiveLine;
- (void)setPrimitiveLine:(NSNumber*)value;

- (short)primitiveLineValue;
- (void)setPrimitiveLineValue:(short)value_;





- (NULDBTestPerson*)primitivePerson;
- (void)setPrimitivePerson:(NULDBTestPerson*)value;


@end
