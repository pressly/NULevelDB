// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestAddress.h instead.

#import <CoreData/CoreData.h>


@class NULDBTestCompany;
@class NULDBTestPerson;






@interface NULDBTestAddressID : NSManagedObjectID {}
@end

@interface _NULDBTestAddress : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (NULDBTestAddressID*)objectID;




@property (nonatomic, retain) NSString *city;


//- (BOOL)validateCity:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSString *postalCode;


//- (BOOL)validatePostalCode:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSString *state;


//- (BOOL)validateState:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSString *street;


//- (BOOL)validateStreet:(id*)value_ error:(NSError**)error_;





@property (nonatomic, retain) NULDBTestCompany* company;

//- (BOOL)validateCompany:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NULDBTestPerson* person;

//- (BOOL)validatePerson:(id*)value_ error:(NSError**)error_;




@end

@interface _NULDBTestAddress (CoreDataGeneratedAccessors)

@end

@interface _NULDBTestAddress (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveCity;
- (void)setPrimitiveCity:(NSString*)value;




- (NSString*)primitivePostalCode;
- (void)setPrimitivePostalCode:(NSString*)value;




- (NSString*)primitiveState;
- (void)setPrimitiveState:(NSString*)value;




- (NSString*)primitiveStreet;
- (void)setPrimitiveStreet:(NSString*)value;





- (NULDBTestCompany*)primitiveCompany;
- (void)setPrimitiveCompany:(NULDBTestCompany*)value;



- (NULDBTestPerson*)primitivePerson;
- (void)setPrimitivePerson:(NULDBTestPerson*)value;


@end
