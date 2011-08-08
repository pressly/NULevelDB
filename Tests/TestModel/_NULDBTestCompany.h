// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestCompany.h instead.

#import <CoreData/CoreData.h>
#import "NULDBTestModel.h"

@class NULDBTestAddress;
@class NULDBTestRole;
@class NULDBTestPerson;




@interface NULDBTestCompanyID : NSManagedObjectID {}
@end

@interface _NULDBTestCompany : NULDBTestModel {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (NULDBTestCompanyID*)objectID;




@property (nonatomic, retain) NSString *name;


//- (BOOL)validateName:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSString *primaryAddressID;


//- (BOOL)validatePrimaryAddressID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, retain) NSSet* addresses;

- (NSMutableSet*)addressesSet;




@property (nonatomic, retain) NSSet* roles;

- (NSMutableSet*)rolesSet;




@property (nonatomic, retain) NSSet* workers;

- (NSMutableSet*)workersSet;




@property (nonatomic, readonly) NSArray *mainAddress;

@property (nonatomic, readonly) NSArray *secondaryAddresses;

@end

@interface _NULDBTestCompany (CoreDataGeneratedAccessors)

- (void)addAddresses:(NSSet*)value_;
- (void)removeAddresses:(NSSet*)value_;
- (void)addAddressesObject:(NULDBTestAddress*)value_;
- (void)removeAddressesObject:(NULDBTestAddress*)value_;

- (void)addRoles:(NSSet*)value_;
- (void)removeRoles:(NSSet*)value_;
- (void)addRolesObject:(NULDBTestRole*)value_;
- (void)removeRolesObject:(NULDBTestRole*)value_;

- (void)addWorkers:(NSSet*)value_;
- (void)removeWorkers:(NSSet*)value_;
- (void)addWorkersObject:(NULDBTestPerson*)value_;
- (void)removeWorkersObject:(NULDBTestPerson*)value_;

@end

@interface _NULDBTestCompany (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;




- (NSString*)primitivePrimaryAddressID;
- (void)setPrimitivePrimaryAddressID:(NSString*)value;





- (NSMutableSet*)primitiveAddresses;
- (void)setPrimitiveAddresses:(NSMutableSet*)value;



- (NSMutableSet*)primitiveRoles;
- (void)setPrimitiveRoles:(NSMutableSet*)value;



- (NSMutableSet*)primitiveWorkers;
- (void)setPrimitiveWorkers:(NSMutableSet*)value;


@end
