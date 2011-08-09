//
//  NULDBDB.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBDB.h"

#include <leveldb/db.h>
#include <leveldb/options.h>


static int logging = 0;

#define NULDBLog(frmt, ...) do{ if(logging) NSLog((frmt), ##__VA_ARGS__); } while(0)


using namespace leveldb;


static Class stringClass;
static Class dataClass;
static Class dictClass;


static inline Slice *NULDBSliceFromObject(id<NSCoding> object) {
    
    char type = 'o';
    
    if([(id)object isKindOfClass:stringClass])    type = 's';
    else if([(id)object isKindOfClass:dataClass]) type = 'd';
    else if([(id)object isKindOfClass:dictClass]) type = 'h';

    NSMutableData *d = [NSMutableData dataWithBytes:&type length:1];

    switch (type) {
        case 's':
            [d appendData:[(NSString *)object dataUsingEncoding:NSUTF8StringEncoding]];
            break;
            
        case 'd':
            [d appendData:(NSData *)object];
            break;
            
        case 'h':
            [d appendData:[NSPropertyListSerialization dataWithPropertyList:(id)object format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL]];
            break;
            
        default:
            [d appendData:[NSKeyedArchiver archivedDataWithRootObject:object]];
            break;
    }
    
    return new Slice((const char *)[d bytes], (size_t)[d length]);
}

static inline id<NSCoding> NULDBObjectFromSlice(Slice *slice) {
    
    NSData *d = [NSData dataWithBytes:slice->data() length:slice->size()];
    NSData *value = [d subdataWithRange:NSMakeRange(1, [d length] - 1)];
    
    char type;
    
    [d getBytes:&type length:1];
    
    switch (type) {
        case 's':
            return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
            break;
            
        case 'd':
            return value;
            break;
            
        case 'h':
            return [NSPropertyListSerialization propertyListWithData:value options:NSPropertyListImmutable format:NULL error:NULL];
            break;
            
        default:
            break;
    }
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}



@interface NULDBDB ()
// These are maybe stupid and a waste of time
- (NSUInteger)classCodeForObject:(id)object;
- (NSUInteger)objectCodeForObject:(id)object;
- (char)valueCodeForObject:(id)object;
@end


namespace NULDB {
    
    /*
     
     objectKey => objectToken
        propertyKey => propertyValue
     
     ?? objectToken => objectKey ?? (would let us find objects after searching on property values)
     
     objectKey:     ("NULDB:"+string)
     	string is the storageKey provided by objects that conform to NULDBSerializable
     
     propertyValue: string | number | archive | plist | objectKey | arrayToken
     
     objectToken:   ('N', 'U', 'O', ' ', c#, o#)
     	c# is the same class number in the classKey
    	o# is the unique integer assigned to the object
     
     arrayToken:    ('N', 'U', 'A', ' ', a#, count)
     	a# is the unique integer assigned to the array
     	count is the number of objects in the array
     
     arrayIndexKey: ('N', 'U', 'I', vc, a#, i#) => propertyValue
     	vc is the type code of the property value ('s'-string, 'd'-data, 'h'-hash aka dictionary, or 'o'-object)
     	a# is the unique integer assigned to the array
     	i# in the non-unique index of the value in the array
     
     propertyKey:   ('N', 'U', 'P', vc, p#, o#)
		vc is the type code of the property value ('a'-array, 's'-string, 'd'-data, 'h'-hash aka dictionary, or 'o'-object)
     	p# is the index to the property in the property names list
     	o# is the unique integer assigned to the owning object
     
     classKey:      ('N', 'U', 'C', ' ', c#, count) => classDescription
     	c# is the unique integer assigned to the class
     	count is the number of properties
     
     classDescription: ("className", propertyNamesList)
     propertyNamesList: ("property1", '|', "property2", '|' ..., '|', "propertyN")
     
     */
    
    class NULDBStorageKey;
    
    class NULDBClassKey;
    class NULDBObjectToken;
    class NULDBArrayToken;
    class NULDBArrayIndexKey;
    class NULDBPropertyKey;
    
    class NULDBStorageKey {
    
    public:
        
        static const char keyTypes[];
        
        static BOOL valid(Slice *slice) {
            
            if(slice->size() < sizeof(NULDBStorageKey))
                return NO;
            
            std::string data = slice->ToString();
            
            if(data[0] != 'N' || data[1] != 'U')
                return NO;
            
            // This doesn't verify the property value code, object code, class code, array code, property index or array index
            for(int i=0; i<5; ++i)
                if(data[2] == keyTypes[i])
                    return YES;
            
            return NO;
        }
        
        NULDBStorageKey() : prefix1('N'), prefix2('U') {}
        
        NULDBStorageKey(char kType, char vType) : prefix1('N'), prefix2('U') {
            keyType = kType;
            valType = vType;
        }

        NULDBStorageKey(Slice &slice) : prefix1('\0'), prefix2('\0') {
       
            struct temp {
                char c[4];
                NSUInteger u[2];
            } temp;
            
            memcpy(&temp, slice.data(), sizeof(temp));
            
            assert(temp.c[0] == 'N');
            assert(temp.c[1] == 'U');
            
            keyType = temp.c[2];
            valType = temp.c[3];
            a = temp.u[0];
            b = temp.u[1];
        }
        
        Slice *slice( void ) {
            return new Slice((const char*)this, sizeof(*this));
        }
        
        NULDBStorageKey *convert(NULDBStorageKey *other);
        
    protected:
        const char prefix1;
        const char prefix2;
        char keyType;
        char valType;
        NSUInteger a;
        NSUInteger b;
    };
    
    const char keyTypes[] = {'O', 'A', 'I', 'P', 'C'};

    
    class NULDBObjectToken : public NULDBStorageKey {
        
    public:
        
        NULDBObjectToken(NSUInteger classCode, NSUInteger objectCode) : NULDBStorageKey('O', ' ') {
            a = classCode;
            b = objectCode;
        }
        
        NULDBObjectToken(NULDBDB *db, id object) : NULDBStorageKey('O', [db valueCodeForObject:object]) {
            a = [db classCodeForObject:object];
            b = [db objectCodeForObject:object];
        }
    };
    
    
    class NULDBArrayToken : public NULDBStorageKey {
   
    public:
        
        NULDBArrayToken(NSUInteger arrayCode, NSUInteger count) : NULDBStorageKey('A', ' ') {
            a = arrayCode;
            b = count;
        }
    };
    
    
    class NULDBArrayIndexKey : public NULDBStorageKey {
     
    public:
        
        NULDBArrayIndexKey(char vType, NSUInteger index, NSUInteger arrayCode) : NULDBStorageKey('I', vType) {
            a = arrayCode;
            b = index;
        }
    };

    class NULDBPropertyKey : public NULDBStorageKey {
    
    public:    

        NULDBPropertyKey(char vType, NSUInteger propertyIndex, NSUInteger objectCode) : NULDBStorageKey('P', vType) {
            a = propertyIndex;
            b = objectCode;
        }
    };
    
    
    class NULDBClassKey : public NULDBStorageKey {
        
    public:
        
        NULDBClassKey(NULDBDB *db, id object) : NULDBStorageKey('C', ' ') {
            a = [db classCodeForObject:object];
            b = [[object properties] count];
        };
        
        NULDBClassKey(NULDBStorageKey *other);
        
        unsigned long classCode() {
            return a;
        }
    };
    

    class NULDBClassDescription {

    public:
        
        NULDBClassDescription(id<NULDBSerializable> object) {
            className = NSStringFromClass([object class]);
            properties = [object propertyNames];
        }
        
        NULDBClassDescription(Slice &slice) {
            
            NSString *temp = [[NSString alloc] initWithUTF8String:slice.ToString().c_str()];
            NSUInteger sepLoc = [temp rangeOfString:@"|"].location;
            
            className = [temp substringToIndex:sepLoc];
            properties = [[temp substringFromIndex:sepLoc+1] componentsSeparatedByString:@","];
        }
        
        Slice *slice() {
            
            NSString *temp = [NSString stringWithFormat:@"%@|%@", className, [properties componentsJoinedByString:@","]];
            
            return new Slice([temp UTF8String]);
        }
        
    private:
        NSString *className;
        NSArray *properties;
    };
    

    class NULDBObjectKey {
        
        static const char PREFIX[6];
      
    public:
        
        NULDBObjectKey(NSString *storageKey) {
            for(int i=0; i<6; ++i)
                prefix[i] = PREFIX[i];
        }
        
        NULDBObjectKey(Slice &slice) {
            memcpy(this, slice.data(), 6*sizeof(char));
            for(int i=0; i<6; ++i)
                assert(prefix[i] == PREFIX[i]);
            storageKey = [[NSString alloc] initWithUTF8String:slice.data()+6];
        }
        
        Slice *slice() {
            
            NSMutableData *d = [NSMutableData dataWithBytes:prefix length:6*sizeof(char)];
            
            [d appendData:[storageKey dataUsingEncoding:NSUTF8StringEncoding]];
            
            return new Slice((const char *)[d bytes], [d length]);
        }
        
    private:
        char prefix[6];
        NSString *storageKey;
    };
    
    const char NULDBObjectKey::PREFIX[6] = { 'N', 'U', 'L', 'D', 'B', ':' };
    
    
    class NULDBCounters {
        
    public:
        
        NULDBCounters(Slice *slice) {
            memcpy(this, slice, sizeof(*this));
        }
      
        Slice *slice() {
            return new Slice((const char *)this, sizeof(*this));
        }
        
        NSUInteger addClass( void ) { return ++classes; }
        NSUInteger addObject( void ) { return ++objects; }
        NSUInteger addArray( void ) { return ++arrays; }
        
    private:
        
        NSUInteger classes;
        NSUInteger objects;
        NSUInteger arrays;
        
    };
    
    static const Slice NULDBCountersKey = Slice("NULDBCounters", sizeof("NULDBCounters"));
}



@interface NULDBDB ()

- (void)storeObject:(id)obj forKey:(NSString *)key;

- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj;

- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)key;

- (void)storeArray:(NSArray *)array forKey:(NSString *)key;
- (NSArray *)unserializeArrayForKey:(NSString *)key;
- (void)deleteStoredArrayContentsForKey:(NSString *)key;

@end


@implementation NULDBDB {
    DB *db;
    ReadOptions readOptions;
    WriteOptions writeOptions;
    Slice *classIndexKey;
}

@synthesize location;

//- (void)dealloc {
//    delete db;
//    [super dealloc];
//}

- (void)finalize {
    delete db;
    delete classIndexKey;
    [super finalize];
}

+ (void)enableLogging {
    if(logging)
        --logging;
}

+ (void)disableLogging {
    ++logging;
}

+ (NSString *)defaultLocation {
    
    NSString *dbFile = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    
    return [dbFile stringByAppendingPathComponent:@"store.db"];
}

+ (void)initialize {
    stringClass = [NSString class];
    dataClass = [NSData class];
    dictClass = [NSDictionary class];
}

- (id)init {
    return [self initWithLocation:[NULDBDB defaultLocation]];
}

- (id)initWithLocation:(NSString *)path {
    
    self = [super init];
    if (self) {
        
        Options options;
        options.create_if_missing = true;
        
        self.location = path;
        
        Status status = DB::Open(options, [path UTF8String], &db);
        
        readOptions.fill_cache = true;
        writeOptions.sync = true;
        
        if(!status.ok()) {
            NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
        }
        
        classIndexKey = new Slice("NULClassIndex");
    }
    
    return self;
}

- (void)destroy {
    Options  options;
    leveldb::DestroyDB([[NULDBDB defaultLocation] UTF8String], options);
}


#pragma mark Basic Key-Value Storage support
- (void)storeValue:(id<NSCoding>)value forKey:(id<NSCoding>)key {

    Slice *k = NULDBSliceFromObject(key);
    Slice *v = NULDBSliceFromObject(value);
    Status status = db->Put(writeOptions, *k, *v);
    
    delete k; delete v;
    
    if(!status.ok())
    {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }
    else
        NULDBLog(@"   PUT->  %@ (%lu bytes)", key, v->size());
}

- (id)storedValueForKey:(id<NSCoding>)key {
        
    std::string v_string;

    Slice *k = NULDBSliceFromObject(key);
    Status status = db->Get(readOptions, *k, &v_string);
    
    delete k;
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }
    else
        NULDBLog(@" <-GET    %@ (%lu bytes)", key, v_string.length());

    Slice v = v_string;

    return NULDBObjectFromSlice(&v);
}

- (void)deleteStoredValueForKey:(id<NSCoding>)key {
    
    Slice *k = NULDBSliceFromObject(key);
    Status status = db->Delete(writeOptions, *k);
    
    delete k;
    
    if(!status.ok())
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
    else
        NULDBLog(@" X-DEL-X   %@", key);
}


#pragma mark Private Relationship Support
/*
 * TODO: Use a more compact, binary key format with keys of identical lengths
 */

- (NSUInteger)classCodeForObject:(id<NULDBSerializable>)object {
    
    NSUInteger result = 0;
    
    NSString *className = NSStringFromClass([object class]);
    std::string value;

#if 1
    NULDB::NULDBClassDescription description(object);
    
//    NULDB::NULDBClassKey classKey(self, object);
//    Slice *classKeySlice = classKey.slice();
//    Status status = db->Get(readOptions, *classKeySlice, &value);
    
    Slice *slice = description.slice();
    Status status = db->Get(readOptions, *slice, &value);
    
    if(status.IsNotFound()) {
        
        // The class is new; load, update and save the counters; then save a new class description
        status = db->Get(readOptions, NULDB::NULDBCountersKey, &value);
        
        assert(status.ok());
        
        Slice *slice = new Slice(value);
        NULDB::NULDBCounters counters(slice);
        
        delete slice;

        result = counters.addClass();
        slice = counters.slice();
        status = db->Put(writeOptions, *classKeySlice, *slice);
        
        delete slice;

        assert(status.ok());

        slice = description.slice();
        
        status = db->Put(writeOptions, *classKeySlice, *slice);
        
        assert(status.ok());

        delete slice;
    }
    else {
    
        // unwrap class 
        assert(status.ok());
    
        Slice *slice = new Slice(value);
        
        
    }
    
    delete classKeySlice;
    
#else    
    /*
     * How should we store our class index?
     *
     * The way below will only get slower and slower as new classes are added
     * so we could just store every entry in its own key, and endure more overhead per class with amortized cost
     *
     */
    NSError *error = nil;
    
    Status status = db->Get(readOptions, *classIndexKey, &value);
    
    if(status.ok()) {

        NSData *data = [NSData dataWithBytesNoCopy:&value length:value.length() freeWhenDone:NO];
        NSMutableDictionary *index = [NSPropertyListSerialization propertyListWithData:data
                                                                               options:NSPropertyListMutableContainers
                                                                                format:NULL
                                                                                 error:&error];
        NSNumber *number = [index objectForKey:className];
        BOOL updateIndex = NO;
        BOOL createIndex = NO;
        
        if(number)
            result = [number unsignedIntegerValue];
        else if(index) {
            result = [[index objectForKey:@"!classCounter"] unsignedIntegerValue]+1;
            updateIndex = YES;
        }
        else {
            createIndex = updateIndex = YES;
        }
        
        if(createIndex) {
            index = [NSMutableDictionary dictionaryWithCapacity:50];
        }
        if(updateIndex) {
            number = [NSNumber numberWithUnsignedInteger:result];
            [index setObject:number forKey:@"!classCounter"];
            [index setObject:number forKey:className];
            
            Slice *indexSlice = NULDBSliceFromObject(index);
            status = db->Put(writeOptions, *classIndexKey, *indexSlice);
            
            delete indexSlice;
            
            if(!status.ok()) {
                // This is probably exception-worthy -- I don't know how to recoover fr
                NSLog(@"Failed to save class index: %s", status.ToString().c_str());
            }
        }
        else {
            NSLog(@"Failed to load class index: %s", status.ToString().c_str());
        }
    }
#endif
    
    return result;
}

- (NSUInteger)objectCodeForObject:(id)object {
    // TODO: implement
    return 0;
}

- (char)valueCodeForObject:(id)object {
    // TODO: Implement
    return 0;
}



#define NULDBClassToken(_class_name_) ([NSString stringWithFormat:@"%@:NUClass", _class_name_])
#define NULDBIsClassToken(_key_) ([_key_ hasSuffix:@"NUClass"])
#define NULDBClassFromToken(_key_) ([_key_ substringToIndex:[_key_ rangeOfString:@":"].location])

#define NULDBPropertyKey(_class_name_, _prop_name_, _obj_key_ ) ([NSString stringWithFormat:@"%@:%@|%@:NUProperty", _prop_name_, _obj_key_, _class_name_])
#define NULDBIsPropertyKey(_key_) ([_key_ hasSuffix:@"NUProperty"])
#define NULDBPropertyIdentifierFromKey(_key_) ([_key_ substringToIndex:[_key_ rangeOfString:@"|"].location])

static inline NSString *NULDBClassFromPropertyKey(NSString *key) {
    
    NSString *classFragment = [key substringFromIndex:[key rangeOfString:@"|"].location+1];
    
    return [classFragment substringToIndex:[key rangeOfString:@":"].location];
}

#define NULDBArrayToken(_class_name_, _count_) ([NSString stringWithFormat:@"%u:%@|NUArray", _count_, _class_name_])
#define NULDBIsArrayToken(_key_) ([_key_ hasSuffix:@"NUArray"])

static inline NSString *NULDBClassFromArrayToken(NSString *token) {

    NSString *fragment = [token substringToIndex:[token rangeOfString:@"|"].location];
    
    return [fragment substringFromIndex:[fragment rangeOfString:@":"].location+1];
}

#define NULDBArrayIndexKey(_key_, _index_) ([NSString stringWithFormat:@"%u:%@:NUIndex", _index_, _key_])
#define NULDBIsArrayIndexKey(_key_) ([_key_ hasSuffix:@"NUIndex"])
#define NULDBArrayCountFromKey(_key_) ([[_key_ substringToIndex:[_key_ rangeOfString:@":"].location] intValue])

/*
 * TODO: Convert stored values and indexes to C++
 */
- (void)storeObject:(id)obj forKey:(NSString *)key {
    
    if([obj conformsToProtocol:@protocol(NULDBPlistTransformable)]) {
        [self storeValue:[NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([obj class]), @"class",
                          [obj plistRepresentation], @"object",
                          nil]
                  forKey:key];
    }
    else if([obj conformsToProtocol:@protocol(NULDBSerializable)]) {
        [self storeValue:[self _storeObject:obj] forKey:key];
    }
    else if([obj isKindOfClass:[NSArray class]]) {
        if([obj count])
            [self storeArray:obj forKey:key];
    }
    else if([obj isKindOfClass:[NSSet class]]) {
        if([obj count])
            [self storeArray:[obj allObjects] forKey:key];
    }
    else if([obj isKindOfClass:[NSDictionary class]]) {
        if([obj count])
            [self storeDictionary:obj forKey:key];
    }
    else if([obj conformsToProtocol:@protocol(NSCoding)])
        [self storeValue:obj forKey:key];
}

// Returns the unique object storage key
- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj {
    
    NSString *className = NSStringFromClass([obj class]);
    NSString *classKey = NULDBClassToken(className);
    NSArray *properties = [self storedValueForKey:classKey];
    NSString *key = [obj storageKey];
    
    NSAssert1(nil != classKey, @"No key for class %@", className);
    NSAssert1(nil != key, @"No storage key for object %@", obj);
    
    NULDBLog(@" ARCHIVE %@", className);
    
    if(nil == properties) {
        properties = [obj propertyNames];
        [self storeValue:properties forKey:classKey];
    }
    
    [self storeValue:classKey forKey:key];
    
    for(NSString *property in properties)
        [self storeObject:[obj valueForKey:property] forKey:NULDBPropertyKey(className, property, key)];

    return key;
}

- (id)unserializeObjectForClass:(NSString *)className key:(NSString *)key {

    NSArray *properties = [self storedValueForKey:NULDBClassToken(className)];
    
    if([properties count] < 1)
        return nil;

    
    id obj = [[NSClassFromString(className) alloc] init];
    
    
    NULDBLog(@" RESTORE %@", className);
    
    for(NSString *property in properties)
        [obj setValue:[self storedObjectForKey:NULDBPropertyKey(className, property, key)] forKey:property];
    
    return obj;
}

// Support for NULDBSerializable objects in the dictionary
- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key {
    
    NSMutableDictionary *lookup = [NSMutableDictionary dictionaryWithCapacity:[plist count]];
        
    for(id dictKey in [plist allKeys]) {
        
        id value = [plist objectForKey:dictKey];
        
        // FIXME: this is lame, should always call the same wrapper
        if([value conformsToProtocol:@protocol(NULDBPlistTransformable)])
            value = [value plistRepresentation];
        else if([value conformsToProtocol:@protocol(NULDBSerializable)])
            value = [self _storeObject:value]; // store the object and replace it with it's lookup key
        
        [lookup setObject:value forKey:dictKey];
    }
    
    [self storeValue:lookup forKey:key];
}

- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict {
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[storedDict count]];
    
    for(NSString *key in [storedDict allKeys]) {
        
        id value = [self storedObjectForKey:key];
        
        if(value)
            [result setObject:value forKey:key];
        else
            [result setObject:[storedDict objectForKey:key] forKey:key];
    }

    return result;
}

- (void)deleteStoredDictionary:(NSDictionary *)storedDict {
    for(NSString *key in [storedDict allKeys])
        [self deleteStoredObjectForKey:key];
}

// Support for NULDBSerializable objects in the array
- (void)storeArray:(NSArray *)array forKey:(NSString *)key {
    
    NSString *propertyFragment = NULDBPropertyIdentifierFromKey(key);
    NSUInteger i=0;
    
    for(id object in array)
        [self storeObject:object forKey:NULDBArrayIndexKey(propertyFragment, i)], i++;
        
    [self storeValue:NULDBArrayToken(NSStringFromClass([[array lastObject] class]), [array count]) forKey:key];
}

- (NSArray *)unserializeArrayForKey:(NSString *)key {
    
    NSString *arrayToken = [self storedValueForKey:key];

    NSUInteger count = NULDBArrayCountFromKey(arrayToken);
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];

    NSString *objcClass = NSClassFromString(NULDBClassFromArrayToken(arrayToken));
    BOOL serialized = ![objcClass conformsToProtocol:@protocol(NULDBPlistTransformable)] && [objcClass conformsToProtocol:@protocol(NULDBSerializable)];

    NSString *propertyFragment = NULDBPropertyIdentifierFromKey(key);

    for(NSUInteger i=0; i<count; i++) {
        
        id storedObj = [self storedObjectForKey:NULDBArrayIndexKey(propertyFragment, i)];
        
        if(serialized)
            storedObj = [self storedObjectForKey:storedObj];
    
        [array addObject:storedObj];
    }
    
    return array;
}

- (void)deleteStoredArrayContentsForKey:(NSString *)key {
    
    NSString *propertyFragment = NULDBPropertyIdentifierFromKey(key);
    NSUInteger count = NULDBArrayCountFromKey([self storedObjectForKey:key]);
    
    for(NSUInteger i=0; i<count; ++i)
        [self deleteStoredObjectForKey:NULDBArrayIndexKey(propertyFragment, i)];
}


#pragma mark Public Relational Serialization support
- (void)storeObject:(NSObject<NULDBSerializable> *)obj {
    [self _storeObject:obj];
}

- (id)storedObjectForKey:(NSString *)key {
        
    id storedObj = [self storedValueForKey:key];
        
    // the key is a property key but we don't really care about that; we just need to reconstruct the dictionary
    if([storedObj isKindOfClass:[NSDictionary class]] && (NULDBIsPropertyKey(key) || NULDBIsArrayIndexKey(key))) {
        
        Class propClass = NSClassFromString([storedObj objectForKey:@"class"]);
        
        if([propClass conformsToProtocol:@protocol(NULDBPlistTransformable)])
            return [[propClass alloc] initWithPropertyList:[storedObj objectForKey:@"object"]];
        else
            return [self unserializeDictionary:storedObj];
    }
    
    if([storedObj isKindOfClass:[NSString class]]) {
        
        if(NULDBIsClassToken(storedObj)) {
            
            NSString *className = NULDBClassFromToken(storedObj);
            Class objcClass = NSClassFromString(className);
            
            if(NULL == objcClass)
                return nil;
            
            if([objcClass conformsToProtocol:@protocol(NULDBSerializable)])
                return [self unserializeObjectForClass:className key:key];
            
            if([objcClass conformsToProtocol:@protocol(NSCoding)])
                return storedObj;
        }

        if(NULDBIsArrayToken(storedObj))
            return [self unserializeArrayForKey:key];
    }

    return storedObj;
}

- (void)deleteStoredObjectForKey:(NSString *)key {
    
    id storedObj = [self storedValueForKey:key];
    
    if([storedObj isKindOfClass:[NSDictionary class]]) {
        [self deleteStoredDictionary:storedObj];
    }
    else if([storedObj isKindOfClass:[NSString class]]) {
        
        if(NULDBIsClassToken(storedObj)) {
            
            NULDBLog(@" DELETE %@", NULDBClassFromToken(storedObj));
            
            for(NSString *property in [self storedValueForKey:storedObj]) {
                
                NSString *propKey = [NSString stringWithFormat:@"NUProperty:%@:%@:%@", storedObj, key, property];
                id propVal = [self storedObjectForKey:propKey];
                id objVal = [self storedObjectForKey:propVal];
                
                if(objVal)
                    [self deleteStoredObjectForKey:propVal];
                
                [self deleteStoredValueForKey:propKey];
            }
        }
        else if(NULDBIsArrayToken(storedObj)) {
            [self deleteStoredArrayContentsForKey:key];
        }
    }
    
    [self deleteStoredValueForKey:key];
}

- (void)iterateWithStart:(NSString *)start limit:(NSString *)limit block:(BOOL (^)(NSString *key, id<NSCoding>value))block {
    
    ReadOptions readopts;
    
    readopts.fill_cache = false;
    
    Iterator*iter = db->NewIterator(readopts);
    Slice *startSlice = NULDBSliceFromObject(start);
    Slice *limitSlice = NULDBSliceFromObject(limit);

    for(iter->Seek(*startSlice); iter->Valid() && iter->key().ToString() < limitSlice->ToString(); iter->Next()) {

        Slice key = iter->key(), value = iter->value();
        
        if(!block((NSString *)NULDBObjectFromSlice(&key), NULDBObjectFromSlice(&value)))
           return;
    }
    
    delete iter;
}


#pragma mark Aggregate support
- (NSDictionary *)storedValuesForKeys:(NSArray *)keys {
    return nil;
}

- (NSDictionary *)storedValuesFromStart:(NSString *)start toLimit:(NSString *)limit {
    
    NSMutableDictionary *tuples = [NSMutableDictionary dictionary];
    
    [self iterateWithStart:start limit:limit block:^(NSString *key, id<NSCoding>value) {
        [tuples setObject:value forKey:key];
        return YES;
    }];
    
    return tuples;
}

@end
