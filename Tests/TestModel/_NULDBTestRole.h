// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to NULDBTestRole.h instead.

#import <CoreData/CoreData.h>
#import "NULDBTestModel.h"

@class NULDBTestCompany;
@class NULDBTestPerson;



@interface NULDBTestRoleID : NSManagedObjectID {}
@end

@interface _NULDBTestRole : NULDBTestModel {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (NULDBTestRoleID*)objectID;




@property (nonatomic, retain) NSString *name;


//- (BOOL)validateName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, retain) NULDBTestCompany* company;

//- (BOOL)validateCompany:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NULDBTestPerson* manager;

//- (BOOL)validateManager:(id*)value_ error:(NSError**)error_;




@end

@interface _NULDBTestRole (CoreDataGeneratedAccessors)

@end

@interface _NULDBTestRole (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;





- (NULDBTestCompany*)primitiveCompany;
- (void)setPrimitiveCompany:(NULDBTestCompany*)value;



- (NULDBTestPerson*)primitiveManager;
- (void)setPrimitiveManager:(NULDBTestPerson*)value;


@end
