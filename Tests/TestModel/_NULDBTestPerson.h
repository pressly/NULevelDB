// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestPerson.h instead.

#import <CoreData/CoreData.h>
#import "NULDBTestModel.h"

@class NULDBTestAddress;
@class NULDBTestCompany;
@class NULDBTestPhone;
@class NULDBTestRole;




@interface NULDBTestPersonID : NSManagedObjectID {}
@end

@interface _NULDBTestPerson : NULDBTestModel {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (NULDBTestPersonID*)objectID;




@property (nonatomic, retain) NSString *firstName;


//- (BOOL)validateFirstName:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSString *lastName;


//- (BOOL)validateLastName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, retain) NULDBTestAddress* address;

//- (BOOL)validateAddress:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NULDBTestCompany* company;

//- (BOOL)validateCompany:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NULDBTestPhone* phone;

//- (BOOL)validatePhone:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NULDBTestRole* role;

//- (BOOL)validateRole:(id*)value_ error:(NSError**)error_;




@end

@interface _NULDBTestPerson (CoreDataGeneratedAccessors)

@end

@interface _NULDBTestPerson (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveFirstName;
- (void)setPrimitiveFirstName:(NSString*)value;




- (NSString*)primitiveLastName;
- (void)setPrimitiveLastName:(NSString*)value;





- (NULDBTestAddress*)primitiveAddress;
- (void)setPrimitiveAddress:(NULDBTestAddress*)value;



- (NULDBTestCompany*)primitiveCompany;
- (void)setPrimitiveCompany:(NULDBTestCompany*)value;



- (NULDBTestPhone*)primitivePhone;
- (void)setPrimitivePhone:(NULDBTestPhone*)value;



- (NULDBTestRole*)primitiveRole;
- (void)setPrimitiveRole:(NULDBTestRole*)value;


@end
