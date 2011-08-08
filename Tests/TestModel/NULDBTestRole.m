#import "NULDBTestRole.h"


@implementation NULDBTestRole

+ (NULDBTestRole *)roleWithName:(NSString *)name company:(NULDBTestCompany *)company manager:(NULDBTestPerson *)person {
   
    NULDBTestRole *role = [NSEntityDescription insertNewObjectForEntityForName:@"Role" inManagedObjectContext:CDBSharedContext()];
    
    role.name = name;
    role.company = company;
    role.manager = person;
    
    [CDBSharedContext() save:NULL];
    
    return role;
}

@end
