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


#define USE_BINARY_KEYS 0


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

- (id)unserializeObjectForKey:(PropertyKey)key;

- (void)storeDictionary:(NSDictionary *)plist forKey:(PropertyKey)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)storedDict;

- (void)storeArray:(NSArray *)array forKey:(PropertyKey)key;
- (NSArray *)unserializeArrayForKey:(PropertyKey)key;
- (void)deleteStoredArrayContentsForKey:(PropertyKey)key;

- (BOOL)checkCounters;
- (void)prepareCounters;

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
    DB *db;
    ReadOptions readOptions;
    WriteOptions writeOptions;
    Slice *classIndexKey;
}

@synthesize location;

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
        
#if USE_BINARY_KEYS
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
#endif
        
        Status status = DB::Open(options, [path UTF8String], &db);
        
        readOptions.fill_cache = true;
        writeOptions.sync = true;
        
        if(!status.ok()) {
            NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
        }
#if USE_BINARY_KEYS
        else {
            if(!exists || ![self checkCounters])
                [self prepareCounters];
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

#if USE_BINARY_KEYS
- (BOOL)checkCounters {
    
    std::string value;
    Status status = db->Get(readOptions, CountersKey, &value);
    
    return !status.IsNotFound();
}

// This will reset the counters!
- (void)prepareCounters {
    
    Counters counters; 
    Status status = db->Put(writeOptions, CountersKey, counters.slice());
    
    assert(status.ok());
    
    // We might want to do some kind of integrity check here
    // For example, if we have any classes, objects or arrays, we may have to count them and fix the counters
}

- (NSUInteger)classCodeForObject:(id<NULDBSerializable>)object {
    
    NSUInteger result = 0;
    
    std::string value;

    Slice slice; // slice is a temp var used repeatedly
    ClassToken *classToken;
    StringKey className(NSStringFromClass([object class]));

    Status status = db->Get(readOptions, className.slice(), &value);
    
    if(status.IsNotFound()) {

        // class is not registered; register it
        // load the counters
        status = db->Get(readOptions, CountersKey, &value);
        assert(status.ok());
        slice = value;
        
        Counters counters(slice);
        // increment the class counter
        classToken = new ClassToken(counters.addClass());
        
        // write the counters back
        status = db->Put(writeOptions, CountersKey, counters.slice());
        assert(status.ok());
        
        // save the class token under the classname key
        status = db->Put(writeOptions, className.slice(), classToken->slice());
        assert(status.ok());
        
        // Since we didn't have a token, we also need to save the class description
        ClassDescription description(object);
        ClassKey classKey(classToken->getName());
        
        status = db->Put(writeOptions, classKey.slice(), description.slice());
        assert(status.ok());
    }
    else {
        assert(status.ok());
        slice = value;
        classToken = new ClassToken(slice);
    }

    result = classToken->getName();

    delete classToken;
    
    return result;
}

- (NSUInteger)objectCodeForObject:(id<NULDBSerializable>)object {
    // TODO: implement
    return 0;
}

- (char)valueCodeForObject:(id<NULDBSerializable>)object {
    // TODO: Implement
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


#if USE_BINARY_KEYS
- (void)storeProperty:(id)obj forKey:(PropertyKey)key {
    
    if([obj conformsToProtocol:@protocol(NULDBPlistTransformable)]) {

    }
    else if([obj conformsToProtocol:@protocol(NULDBSerializable)]) {

    }
    else if([obj isKindOfClass:[NSArray class]]) {
        if([obj count]) {
            
        }
    }
    else if([obj isKindOfClass:[NSSet class]]) {
        if([obj count]) {
            
        }
    }
    else if([obj isKindOfClass:[NSDictionary class]]) {
        if([obj count]) {
            
        }
    }
    else if([obj conformsToProtocol:@protocol(NSCoding)]) {
        
    }
}

#else
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
#endif


// Returns the unique object storage key
- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj {
    
    NSString *key = [obj storageKey];
    
#if USE_BINARY_KEYS
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
    
#else
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
#endif

    return key;
}

#if USE_BINARY_KEYS
- (id)unserializeObjectForKey:(PropertyKey)key {
    
    // TODO: Implement
    return nil;
}

- (void)storeDictionary:(NSDictionary *)plist forKey:(PropertyKey)key {
    
    // TODO: Implement
}

- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict {
    
    // TODO: Implement
    return nil;
}

- (void)deleteStoredDictionary:(NSDictionary *)storedDict {
    
    // TODO: Implement
}

- (void)storeArray:(NSArray *)array forKey:(PropertyKey)key {
    
    // TODO: Implement
}

- (NSArray *)unserializeArrayForKey:(PropertyKey)key {
    
    // TODO: Implement
    return nil;
}

- (void)deleteStoredArrayContentsForKey:(PropertyKey)key {
    
    // TODO: Implement
}

#else
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
    [self _storeObject:obj];
}

- (id)storedObjectForKey:(NSString *)key {
        
#if USE_BINARY_KEYS
    // TODO: Implement
    return nil;
    
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
