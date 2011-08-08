#import "_NULDBTestRole.h"


@class NULDBTestPerson, NULDBTestCompany;

@interface NULDBTestRole : _NULDBTestRole {}

+ (NULDBTestRole *)roleWithName:(NSString *)name company:(NULDBTestCompany *)company manager:(NULDBTestPerson *)person;

@end
