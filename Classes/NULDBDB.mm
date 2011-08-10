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


#define USE_BINARY_KEYS 1


#include "NULDBUtilities.h"
#if USE_BINARY_KEYS
#include "NULDBStorageKey.h"
using namespace NULDB;
#endif

static int logging = 0;


using namespace leveldb;


@interface NULDBDB ()

#if USE_BINARY_KEYS
- (void)storeProperty:(id)property forKey:(PropertyKey)key;

- (ObjectKey)serializeObject:(id<NULDBSerializable>)object;
- (id)unserializeObjectForKey:(ObjectKey)key;

- (NSDictionary *)storeDictionary:(NSDictionary *)plist forKey:(PropertyKey)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)storedDict;

- (ArrayKey)storeArray:(NSArray *)array forKey:(PropertyKey)key;
- (NSArray *)unserializeArrayForKey:(ArrayKey)key;
- (void)deleteStoredArrayContentsForKey:(PropertyKey)key;

- (BOOL)checkCounters;
- (void)saveCounters;

#else
- (void)storeObject:(id)obj forKey:(NSString *)key;

- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj;

- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)storedDict;

- (void)storeArray:(NSArray *)array forKey:(NSString *)key;
- (NSArray *)unserializeArrayForKey:(NSString *)key;
- (void)deleteStoredArrayContentsForKey:(NSString *)key;
#endif

@end


@implementation NULDBDB {
    Counters *counters;
    DB *db;
    ReadOptions readOptions;
    WriteOptions writeOptions;
    Slice *classIndexKey;
}

@synthesize location;

- (void)finalize {
    delete counters;
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
#if USE_BINARY_KEYS
        else {
            if(![self checkCounters])
                [self saveCounters];
        }
#endif
        
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

    Slice k = NULDBSliceFromObject(key);
    Slice v = NULDBSliceFromObject(value);
    Status status = db->Put(writeOptions, k, v);
        
    if(!status.ok())
    {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }
    else
        NULDBLog(@"   PUT->  %@ (%lu bytes)", key, v.size());
}

- (id)storedValueForKey:(id<NSCoding>)key {
        
    std::string v_string;

    Slice k = NULDBSliceFromObject(key);
    Status status = db->Get(readOptions, k, &v_string);
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }
    else
        NULDBLog(@" <-GET    %@ (%lu bytes)", key, v_string.length());

    Slice v = v_string;

    return NULDBObjectFromSlice(v);
}

- (void)deleteStoredValueForKey:(id<NSCoding>)key {
    
    Slice k = NULDBSliceFromObject(key);
    Status status = db->Delete(writeOptions, k);
    
    if(!status.ok())
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
    else
        NULDBLog(@" X-DEL-X   %@", key);
}


#pragma mark Private Relationship Support

#if USE_BINARY_KEYS
- (BOOL)checkCounters {
    
    std::string value;
    Status status = db->Get(readOptions, CountersKey, &value);
    
    if(!status.IsNotFound()) {
        assert(status.ok());
        
        Slice slice = value;
        
        counters = new Counters(slice);
    }
    else {
        counters = new Counters();
    }
    
    return !status.IsNotFound();
}

// This will reset the counters!
- (void)saveCounters {
    
    Status status = db->Put(writeOptions, CountersKey, counters->slice());
    
    assert(status.ok());
    
    // We might want to do some kind of integrity check here
    // For example, if we have any classes, objects or arrays, we may have to count them and fix the counters
}

- (NSUInteger)classCodeForObject:(id<NULDBSerializable>)object {
    
    NSUInteger result = 0;
    
    std::string value;

    StringKey className(NSStringFromClass([object class]));
    Status status = db->Get(readOptions, className.slice(), &value);
    ClassKey *classKey;
    
    if(status.IsNotFound()) {

        // class is not registered; register it
        // increment the class counter
        classKey = new ClassKey(counters->addClass());
        
        [self saveCounters];
        
        // save the class token under the classname key
        status = db->Put(writeOptions, className.slice(), classKey->slice());
        assert(status.ok());
        
        // Since we didn't have a token, we also need to save the class description
        ClassDescription description(object);
        
        status = db->Put(writeOptions, classKey->slice(), description.slice());
        assert(status.ok());
    }
    else {
        assert(status.ok());
        Slice slice = value;
        classKey = new ClassKey(slice);
    }

    result = classKey->getName();

    delete classKey;
    
    return result;
}

- (NSUInteger)objectCodeForObject:(id<NULDBSerializable>)object {
    
    NSUInteger result = 0;
    
    std::string value;

    StringKey key = StringKey([object storageKey]);
    Status status = db->Get(readOptions, key.slice(), &value);
    ObjectKey *objectKey;
    
    if(status.IsNotFound()) {
        
        // add a token for the object - don't store the object key until we store the object itself
                
        // update the counters
        objectKey = new ObjectKey(counters->addObject(), [self classCodeForObject:object]);
        
        [self saveCounters];
        
        status = db->Put(writeOptions, key.slice(), objectKey->slice());
        assert(status.ok());
        
        result = objectKey->getName();
    }
    else {
        assert(status.ok());
        Slice slice = value;
        objectKey = new ObjectKey(slice);
    }
    
    result = objectKey->getName();
    
    return result;
}

- (NSUInteger)arrayCodeForArray:(NSArray *)array {
    return 0;
}


#else
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
#endif


#define NULDBWrappedObject(_object_) ([NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([_object_ class]), @"class", [_object_ plistRepresentation], @"object", nil])
#define NULDBUnwrappedObject(_dict_, _class_) ([[_class_ alloc] initWithPropertyList:[(NSDictionary *)_dict_ objectForKey:@"object"]])


#if USE_BINARY_KEYS
- (void)storeProperty:(id)obj forKey:(PropertyKey)key {
    
    Slice valueSlice;
    
    if([obj conformsToProtocol:@protocol(NULDBPlistTransformable)]) {
        valueSlice = NULDBSliceFromObject(NULDBWrappedObject(obj));
    }
    else if([obj conformsToProtocol:@protocol(NULDBSerializable)]) {
        valueSlice = [self serializeObject:obj].slice();
    }
    else if([obj isKindOfClass:[NSArray class]]) {
        if([obj count])
            [self storeArray:obj forKey:key];
        return;
    }
    else if([obj isKindOfClass:[NSSet class]]) {
        if([obj count])
            [self storeArray:[obj allObjects] forKey:key];
        return;
    }
    else if([obj isKindOfClass:[NSDictionary class]]) {
        if([obj count])
            [self storeDictionary:obj forKey:key];
        return;
    }
    else if([obj conformsToProtocol:@protocol(NSCoding)]) {
        valueSlice = NULDBSliceFromObject(obj);
    }
    
   
    Status status = db->Put(writeOptions, key.slice(), valueSlice);
    assert(status.ok());
}

- (id)decodeObject:(id)object {
    
    if([object isKindOfClass:[NSDictionary class]])
        return [self unserializeDictionary:object];
    
    return nil;
}

- (id)propertyForKey:(PropertyKey)key {
    
    std::string tempValue;
    Status status = db->Get(readOptions, key.slice(), &tempValue);
    
    assert(status.ok());
    
    // value can be any of string | number | archive | plist | objectKey | arrayKey
    Slice slice = tempValue;
    
    switch (getKeyType(slice)) {
        case 'O':
            return [self unserializeObjectForKey:ObjectKey(slice)];
            break;
            
        case 'A':
            return [self unserializeArrayForKey:ArrayKey(slice)];
            break;

        case '\0':
            return [self decodeObject:NULDBObjectFromSlice(slice)];
            break;

        default:
            break;
    }
    
    
    return nil;
}

#else
- (void)storeObject:(id)obj forKey:(NSString *)key {
    
    if([obj conformsToProtocol:@protocol(NULDBPlistTransformable)]) {
        [self storeValue:NULDBWrappedObject(obj) forKey:key];
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
#endif


// Returns the unique object storage key
#if USE_BINARY_KEYS
- (ObjectKey)serializeObject:(NSObject<NULDBSerializable> *)obj {
    
    NSString *key = [obj storageKey];
    NSArray *properties = [obj propertyNames];
    
    StringKey objectName(key);
    ObjectKey objectKey(self, obj);
    
    // Store the name/key as key/value pairs of one another
    Status status = db->Put(writeOptions, objectName.slice(), objectKey.slice());
    assert(status.ok());
    status = db->Put(writeOptions, objectKey.slice(), objectName.slice());
    assert(status.ok());
    
    // TODO: make sure pre-existing class definitions match the provided? OR is that too much work to do now?
    
    int i=0;
    
    for(NSString *property in properties) {
        
        PropertyKey propertyKey(i++, objectKey.getName());
        
        [self storeProperty:[obj valueForKey:property] forKey:propertyKey];
    }
    
    return objectKey;
}

- (id)unserializeObjectForKey:(ObjectKey)objectKey {
    
    std::string tempValue;
    ClassKey classKey(objectKey.getClassName());
    
    Status status = db->Get(readOptions, classKey.slice(), &tempValue);
    assert(status.ok());
    Slice slice = tempValue;
    
    ClassDescription classDesc(slice);
    Class objcClass = NSClassFromString(classDesc.getClassName());
    NSArray *properties = classDesc.getProperties();
    id object = [[objcClass alloc] init];
    
    int i=0;
    
    for(NSString *property in properties) {
        
        PropertyKey propertyKey(i++, objectKey.getName());
        
        [object setValue:[self propertyForKey:propertyKey] forKey:property];
    }

    return nil;
}

- (NSDictionary *)storeDictionary:(NSDictionary *)dictionary forKey:(PropertyKey)propertyKey {
    
    // TODO: Implement
    // replace serializable or plist transformable objects in dictionary with stored representations
    // for each serializable object, serialize it
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
    
    int i = 0;
    for (id key in [dictionary allKeys]) {
        
        id obj = [dictionary objectForKey:key];
        
        if([obj conformsToProtocol:@protocol(NULDBPlistTransformable)]) {
            obj = NULDBWrappedObject(obj);
        }
        else if([obj conformsToProtocol:@protocol(NULDBSerializable)]) {
            obj = [self serializeObject:obj].to_data();
        }
        else if([obj isKindOfClass:[NSArray class]]) {
            if([obj count])
                obj = [self storeArray:obj forKey:propertyKey].to_data();
        }
        else if([obj isKindOfClass:[NSSet class]]) {
            if([obj count])
                obj = [self storeArray:[obj allObjects] forKey:propertyKey].to_data();
        }
        else if([obj isKindOfClass:[NSDictionary class]]) {
            if([obj count])
                obj = [self storeDictionary:obj forKey:propertyKey];
        }
        
        [newDict setObject:obj forKey:key];
    }
    
    return newDict;
}

- (id)unserializeDictionary:(NSDictionary *)storedDict {
        
    Class objcClass = NSClassFromString([storedDict objectForKey:@"class"]);
    
    if([objcClass conformsToProtocol:@protocol(NULDBPlistTransformable)])
        return NULDBUnwrappedObject(storedDict, objcClass);
    
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[storedDict count]];
    
    for(NSString *key in [storedDict allKeys]) {
        // TODO: FINISH
    }
    
    return dictionary;
}

- (void)deleteStoredDictionary:(NSDictionary *)storedDict {
    
    // TODO: Implement
}

- (ArrayKey)storeArray:(NSArray *)array forKey:(PropertyKey)key {
    
    // TODO: Implement
    
    
    ArrayKey arrayKey(' ', [self arrayCodeForArray:array], [array count]);
    
    
    return arrayKey;

}

- (NSArray *)unserializeArrayForKey:(ArrayKey)key {
    
    // TODO: Implement
    return nil;
}

- (void)deleteStoredArrayContentsForKey:(PropertyKey)key {
    
    // TODO: Implement
}

#else
- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj {
    
    NSString *key = [obj storageKey];
    
    NSString *className = NSStringFromClass([obj class]);
    NSString *classKey = NULDBClassToken(className);
    NSArray *properties = [self storedValueForKey:classKey];
    
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
#endif


#pragma mark Public Relational Serialization support
- (void)storeObject:(NSObject<NULDBSerializable> *)obj {
#if USE_BINARY_KEYS
    [self serializeObject:obj];
#else
    [self _storeObject:obj];
#endif
}

- (id)storedObjectForKey:(NSString *)key {
        
#if USE_BINARY_KEYS
    StringKey stringKey(key);
    std::string tempValue;
    
    Status status = db->Get(readOptions, StringKey(key).slice(), &tempValue);
    
    if(status.IsNotFound())
        return nil;
    
    assert(status.ok());
    
    Slice slice = tempValue;
    ObjectKey objectKey(slice);

    return [self unserializeObjectForKey:objectKey];
    
#else
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
#endif
}

- (void)deleteStoredObjectForKey:(NSString *)key {
    
#if USE_BINARY_KEYS
    // TODO: Implement
    
#else
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
#endif
}

- (void)iterateWithStart:(NSString *)start limit:(NSString *)limit block:(BOOL (^)(NSString *key, id<NSCoding>value))block {
    
    ReadOptions readopts;
    
    readopts.fill_cache = false;
    
    Iterator*iter = db->NewIterator(readopts);
    Slice startSlice = NULDBSliceFromObject(start);
    Slice limitSlice = NULDBSliceFromObject(limit);

    for(iter->Seek(startSlice); iter->Valid() && iter->key().ToString() < limitSlice.ToString(); iter->Next()) {

        Slice key = iter->key(), value = iter->value();
        
        if(!block((NSString *)NULDBObjectFromSlice(key), NULDBObjectFromSlice(value)))
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
