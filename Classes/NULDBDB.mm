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

using namespace leveldb;


static inline Slice *NULDBSliceFromObject(id<NSCoding> object) {
    
    NSData *d = [NSKeyedArchiver archivedDataWithRootObject:object];
    
    return new Slice((const char *)[d bytes], (size_t)[d length]);
}

static inline id<NSCoding> NULDBObjectFromSlice(Slice *slice) {
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithBytes:slice->data() length:slice->size()]];
}


@interface NULDBDB ()

- (void)storeObject:(id)obj forKey:(NSString *)key;

- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj;

- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)key;

- (void)storeArray:(NSArray *)array forKey:(NSString *)key;
- (NSArray *)unserializeArrayForKey:(NSString *)key;
- (void)deleteStoredArrayContentsForKey:(NSString *)key;

@end


@implementation NULDBDB {
    DB *db;
}

@synthesize location;

//- (void)dealloc {
//    delete db;
//    [super dealloc];
//}

+ (NSString *)defaultLocation {
    
    NSString *dbFile = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    
    return [dbFile stringByAppendingPathComponent:@"store.db"];
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
        
        if(!status.ok()) {
            NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
        }
    }
    
    return self;
}

- (void)destroy {
    Options  options;
    leveldb::DestroyDB([[NULDBDB defaultLocation] UTF8String], options);
}


#pragma mark Basic Key-Value Storage support
- (void)storeValue:(id<NSCoding>)value forKey:(id<NSCoding>)key {
    
    WriteOptions write_options;
    write_options.sync = true;
    
#if 1
    Slice *k = NULDBSliceFromObject(key);
    Slice *v = NULDBSliceFromObject(value);
    Status status = db->Put(write_options, *k, *v);
    
    delete k; delete v;
    
#else
    NSData *dk = [NSKeyedArchiver archivedDataWithRootObject:key], *dv = [NSKeyedArchiver archivedDataWithRootObject:value];
    
    Slice k = Slice((const char *)[dk bytes], (size_t)[dk length]);
    Slice v = Slice((const char *)[dv bytes], (size_t)[dv length]);
    
    Status status = db->Put(write_options, k, v);
#endif
    
    if(!status.ok()) {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }
}

- (id)storedValueForKey:(id<NSCoding>)key {
    
    ReadOptions options;
    options.fill_cache = true;
    
    std::string v_string;
#if 1
    Slice *k = NULDBSliceFromObject(key);
    Status status = db->Get(options, *k, &v_string);
    
    delete k;
    
#else
    NSData *dk = [NSKeyedArchiver archivedDataWithRootObject:key];
    Slice k = Slice((const char *)[dk bytes], (size_t)[dk length]);
    
    Status status = db->Get(options, k, &v_string);
#endif
    
    if(!status.ok()) {
        if(!status.IsNotFound())
            NSLog(@"Problem retrieving value for key '%@' from database: %s", key, status.ToString().c_str());
        return nil;
    }

    Slice v = v_string;

    return NULDBObjectFromSlice(&v);
}

- (void)deleteStoredValueForKey:(id<NSCoding>)key {
    
    WriteOptions write_options;
    write_options.sync = true;

#if 1
    Slice *k = NULDBSliceFromObject(key);
    Status status = db->Delete(write_options, *k);
    
    delete k;
    
#else
    NSData *dk = [NSKeyedArchiver archivedDataWithRootObject:key];
    Slice k = Slice((const char *)[dk bytes], (size_t)[dk length]);
    
    Status status = db->Delete(write_options, k);
#endif
    
    if(!status.ok())
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
}


#pragma mark Private Relationship Support
/*
 * TODO: Use a more compact, binary key format with keys of identical lengths
 */

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

#define NULDBArrayToken(_key_, _count_) ([NSString stringWithFormat:@"%u:NUArray", _count_, _key_])
#define NULDBIsArrayToken(_key_) ([_key_ hasSuffix:@"NUArray"])

#define NULDBArrayIndexKey(_key_, _index_) ([NSString stringWithFormat:@"%u:%@:NUIndex", _index_, _key_])
#define NULDBIsArrayIndexKey(_key_) ([_key_ hasSuffix:@"NUIndex"])
#define NULDBArrayCountFromKey(_key_) ([[_key_ substringToIndex:[_key_ rangeOfString:@":"].location] intValue])

/*
 * TODO: Convert stored values and indexes to C++
 */
- (void)storeObject:(id)obj forKey:(NSString *)key {
    
    if([obj conformsToProtocol:@protocol(NULDBSerializable)]) {
        [self _storeObject:obj];
    }
    else if([obj conformsToProtocol:@protocol(NULDBPlistTransformable)]) {
        [self storeValue:[NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([obj class]), @"class",
                          [obj plistRepresentation], @"object",
                          nil]
                  forKey:key];
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
    
    for(NSString *property in properties)
        [obj setValue:[self storedObjectForKey:NULDBPropertyKey(className, property, key)] forKey:property];
    
    return obj;
}

// Support for NULDBSerializable objects in the dictionary
- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key {
    
    NSMutableDictionary *lookup = [NSMutableDictionary dictionaryWithCapacity:[plist count]];
    
    for(id dictKey in [plist allKeys]) {
        
        id value = [plist objectForKey:dictKey];
        
        if([value conformsToProtocol:@protocol(NULDBSerializable)])
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

    [self storeValue:[NSString stringWithFormat:@"%u:NUArray", [array count]] forKey:key];
}

- (NSArray *)unserializeArrayForKey:(NSString *)key {
    
    NSString *propertyFragment = NULDBPropertyIdentifierFromKey(key);
    NSUInteger count = NULDBArrayCountFromKey([self storedObjectForKey:key]);
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    
    for(NSUInteger i=0; i<count; i++)
        [array addObject:[self storedObjectForKey:NULDBArrayIndexKey(propertyFragment, i)]];
    
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
    if([storedObj isKindOfClass:[NSDictionary class]] && NULDBIsPropertyKey(key)) {
        
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
