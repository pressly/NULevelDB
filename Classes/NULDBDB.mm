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
#include <leveldb/comparator.h>


#include "NULDBUtilities.h"

static int logging = 0;


using namespace leveldb;


@interface NULDBDB ()

- (void)storeObject:(id)obj forKey:(NSString *)key;

- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj;

- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)storedDict;

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


#pragma mark - Generic NSCoding Access
- (BOOL)storeValue:(id<NSCoding>)value forKey:(id<NSCoding>)key {

    Slice k = NULDBSliceFromObject(key);
    Slice v = NULDBSliceFromObject(value);
    Status status = db->Put(writeOptions, k, v);
        
    if(!status.ok())
    {
        NSLog(@"Problem storing key/value pair in database: %s", status.ToString().c_str());
    }
    else
        NULDBLog(@"   PUT->  %@ (%lu bytes)", key, v.size());
    
    return (BOOL)status.ok();
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

- (BOOL)deleteStoredValueForKey:(id<NSCoding>)key {
    
    Slice k = NULDBSliceFromObject(key);
    Status status = db->Delete(writeOptions, k);
    
    if(!status.ok())
        NSLog(@"Problem deleting key/value pair in database: %s", status.ToString().c_str());
    else
        NULDBLog(@" X-DEL-X   %@", key);
    
    return (BOOL)status.ok();
}

/*
 - one for UInt64->Data access
 - one for Data->Data access
 All three of these interfaces will share un underlying fast functional implementation that converts between the exposed types and the native storage format used by the leveldb.
 */
#pragma mark - Streamlined Access Interfaces
#pragma mark Private Access Functions


NSString *NULDBErrorDomain = @"NULevelDBErrorDomain";


#define NULDBSliceFromData(_data_) (Slice((char *)[_data_ bytes], [_data_ length]))
#define NULDBDataFromSlice(_slice_) ([NSData dataWithBytes:_slice_.data() length:_slice_.size()])

#define NULDBSliceFromString(_string_) (Slice((char *)[_string_ UTF8String], [_string_ lengthOfBytesUsingEncoding:NSUTF8StringEncoding]))
#define NULDBStringFromSlice(_slice_) ([NSString stringWithCString:_slice_.data() encoding:NSUTF8StringEncoding])

inline BOOL NULDBStoreValueForKey(DB *db, WriteOptions &options, Slice &key, Slice &value, NSError **error) {
    
    Status status = db->Put(options, key, value);

    if(!status.ok()) {
        if(NULL != error) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSString stringWithUTF8String:status.ToString().c_str()], NSLocalizedDescriptionKey,
//                                      NSLocalizedString(@"", @""), NSLocalizedRecoverySuggestionErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:NULDBErrorDomain code:1 userInfo:userInfo];
        }
        else {
            NSLog(@"Failed to store value in database: %s", status.ToString().c_str());
        }
        return NO;
    }
    
    return YES;
}

inline BOOL NULDBLoadValueForKey(DB *db, ReadOptions &options, Slice &key, id *retValue, BOOL isString, NSError **error) {
    
    std::string tempValue;
    Status status = db->Get(options, key, &tempValue);
    
    assert(NULL != retValue);
    
    if(!status.IsNotFound()) {
        if(!status.ok()) {
            if(NULL != error) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSString stringWithUTF8String:status.ToString().c_str()], NSLocalizedDescriptionKey,
//                                          NSLocalizedString(@"", @""), NSLocalizedRecoverySuggestionErrorKey,
                                          nil];
                *error = [NSError errorWithDomain:NULDBErrorDomain code:2 userInfo:userInfo];
            }
            else {
                NSLog(@"Failed to load value from database: %s", status.ToString().c_str());
            }
            
            *retValue = nil;
            
            return NO;
        }
        else {
            
            Slice value = tempValue;
            
            if(isString)
                *retValue = NULDBStringFromSlice(value);
            else
                *retValue = NULDBDataFromSlice(value);
        }
    }
    else
        *retValue = nil;
    
    if(NULL != error)
        *error = nil;
    
    return YES;
}

inline BOOL NULDBDeleteValueForKey(DB *db, WriteOptions &options, Slice &key, NSError **error) {
    
    Status status = db->Delete(options, key);
    
    if(!status.ok() && !status.IsNotFound()) {
        if(NULL != error) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSString stringWithUTF8String:status.ToString().c_str()], NSLocalizedDescriptionKey,
//                                      NSLocalizedString(@"", @""), NSLocalizedRecoverySuggestionErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:NULDBErrorDomain code:3 userInfo:userInfo];
        }
        else {
            NSLog(@"Failed to delete value in database: %s", status.ToString().c_str());
        }
        return NO;
    }
    return YES;
}


#pragma mark Data->Data Access
- (BOOL)storeData:(NSData *)data forDataKey:(NSData *)key error:(NSError **)error {
    Slice k = NULDBSliceFromData(key), v = NULDBSliceFromData(data);
    return NULDBStoreValueForKey(db, writeOptions, k, v, error);
}

- (NSData *)storedDataForDataKey:(NSData *)key error:(NSError **)error {
    NSData *result = nil;
    Slice k = NULDBSliceFromData(key);
    NULDBLoadValueForKey(db, readOptions, k, &result, NO, error);
    return result;
}

- (BOOL)deleteStoredDataForDataKey:(NSData *)key error:(NSError **)error {
    Slice k = NULDBSliceFromData(key);
    return NULDBDeleteValueForKey(db, writeOptions, k, error);
}


#pragma mark String->Data->Data Access

#define OptionallyUseBlockEncoder(_key_, _block_) (_block_ ? _block_(_key_) : [key dataUsingEncoding:NSUTF8StringEncoding])

- (BOOL)storeData:(NSData *)data forKey:(NSString *)key translator:(NSData *(^)(NSString *))block error:(NSError **)error {
    Slice k = NULDBSliceFromData(OptionallyUseBlockEncoder(key, block)), v = NULDBSliceFromData(data);
    return NULDBStoreValueForKey(db, writeOptions, k, v, error);
}

- (NSData *)storedDataForKey:(NSString *)key translator:(NSData *(^)(NSString *))block error:(NSError **)error {
    NSData *result = nil;
    Slice k = NULDBSliceFromData(OptionallyUseBlockEncoder(key, block)), v;
    NULDBLoadValueForKey(db, readOptions, k, &result, NO, error);
    return result;
}

- (BOOL)deleteStoredDataForKey:(NSString *)key translator:(NSData *(^)(NSString *))block error:(NSError **)error {
    Slice k = NULDBSliceFromData(OptionallyUseBlockEncoder(key, block));
    return NULDBDeleteValueForKey(db, writeOptions, k, error);
}


#pragma mark String->Data Access
- (BOOL)storeData:(NSData *)data forKey:(NSString *)key error:(NSError **)error {
    Slice k = NULDBSliceFromString(key), v = NULDBSliceFromData(data);
    return NULDBStoreValueForKey(db, writeOptions, k, v, error);
}

- (NSData *)storedDataForKey:(NSString *)key error:(NSError **)error {
    NSData *result = nil;
    Slice k = NULDBSliceFromString(key);
    NULDBLoadValueForKey(db, readOptions, k, &result, NO, error);
    return result;
}

- (BOOL)deleteStoredDataForKey:(NSString *)key error:(NSError **)error {
    Slice k = NULDBSliceFromString(key);
    return NULDBDeleteValueForKey(db, writeOptions, k, error);
}


#pragma mark String->String Access
- (BOOL)storeString:(NSString *)string forKey:(NSString *)key error:(NSError **)error {
    Slice k = NULDBSliceFromString(key), v = NULDBSliceFromString(string);
    return NULDBStoreValueForKey(db, writeOptions, k, v, error);
}

- (NSString *)storedStringForKey:(NSString *)key error:(NSError **)error {
    NSString *result = nil;
    Slice k = NULDBSliceFromString(key);
    NULDBLoadValueForKey(db, readOptions, k, &result, YES, error);
    return result;
}


#pragma mark Index->Data Access
- (BOOL)storeData:(NSData *)data forIndexKey:(uint64_t)key error:(NSError **)error {
    Slice k((char *)&key, sizeof(uint64_t)), v = NULDBSliceFromData(data);
    return NULDBStoreValueForKey(db, writeOptions, k, v, error);
}

- (NSData *)storedDataForIndexKey:(uint64_t)key error:(NSError **)error {
    NSData *result = nil;
    Slice k((char *)&key, sizeof(uint64_t));
    NULDBLoadValueForKey(db, readOptions, k, &result, NO, error);
    return result;
}

- (BOOL)deleteStoredDataForIndexKey:(uint64_t)key error:(NSError **)error {
    Slice k((char *)&key, sizeof(uint64_t));
    return NULDBDeleteValueForKey(db, writeOptions, k, error);
}


#pragma mark - Private Relationship Support

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


#define NULDBWrappedObject(_object_) ([NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([_object_ class]), @"class", [_object_ plistRepresentation], @"object", nil])
#define NULDBUnwrappedObject(_dict_, _class_) ([[_class_ alloc] initWithPropertyList:[(NSDictionary *)_dict_ objectForKey:@"object"]])


#pragma mark - Basic Serialization
#pragma mark Generic Objects
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

#pragma mark Dictionaries
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

#pragma mark Arrays
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


#pragma mark - Public Interface
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


#pragma mark Bulk Save and Load
- (BOOL)storeValuesFromDictionary:(NSDictionary *)dictionary {
    
    for(id key in [dictionary allKeys]) {
        if(![self storeValue:[dictionary objectForKey:key] forKey:key])
            return NO;
    }
    
    return YES;
}

- (NSDictionary *)storedValuesForKeys:(NSArray *)keys {
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[keys count]];
    
    for(id key in keys) {
        
        id value = [self storedValueForKey:key];
        
        if(nil != value)
            [result setObject:value forKey:key];
    }
    
    return [NSDictionary dictionaryWithDictionary:result];
}

- (BOOL)deleteStoredValuesForKeys:(NSArray *)keys {
    
    for(id key in keys) {
        if(![self deleteStoredValueForKey:key])
           return NO;
    }
    
    return YES;
}

// Data values and keys
- (BOOL)storeDataFromDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    
    for(id key in [dictionary allKeys]) {
        
        Slice k = NULDBSliceFromData(key), v = NULDBSliceFromData([dictionary objectForKey:key]);
        
        if(!NULDBStoreValueForKey(db, writeOptions, k, v, error))
            return NO;
    }
    
    return YES;
}

- (NSDictionary *)storedDataForKeys:(NSArray *)keys error:(NSError **)error {
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[keys count]];
    
    for(id key in keys) {
        
        NSData *result = nil;
        Slice k = NULDBSliceFromData(key);
        if(!NULDBLoadValueForKey(db, readOptions, k, &result, NO, error))
            if (4 == [*error code])
                continue;
            else
                return nil;
        
        [dictionary setObject:result forKey:key]; 
    }
        
        return [NSDictionary dictionaryWithDictionary:dictionary];
}

- (BOOL)deleteStoredDataForKeys:(NSArray *)keys error:(NSError **)error {
    
    for(id key in keys) {
        
        Slice k = NULDBSliceFromData(key);
        if(!NULDBDeleteValueForKey(db, writeOptions, k, error))
            return NO;
    }
    
    return YES;
}

- (BOOL)storeDataFromArray:(NSArray *)array forIndexes:(uint64_t *)indexes error:(NSError **)error {
    
    uint64_t *currentIndex = indexes;
    
    for(NSData *data in array) {
        
        Slice k((char *)currentIndex++, sizeof(uint64_t)), v = NULDBSliceFromData(data);
        if(!NULDBStoreValueForKey(db, writeOptions, k, v, error))
            return NO;
    }
    
    return YES;
}

- (NSArray *)storedDataForIndexes:(uint64_t *)indexes count:(NSUInteger)count error:(NSError **)error {
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    
    NSData *result = nil;

    for(int i=0; i<count; ++i) {
        
        uint64_t index = indexes[i];
        Slice k((char *)&index, sizeof(uint64_t));
        if(!NULDBLoadValueForKey(db, readOptions, k, &result, NO, error))
            if (4 == [*error code])
                continue;
            else
                return nil;

        [array addObject:result];
    }

    return [NSArray arrayWithArray:array];
}

- (BOOL)deleteStoredDataForIndexes:(uint64_t *)indexes count:(NSUInteger)count error:(NSError **)error {
    
    for(NSUInteger i=0; i<count; ++i) {
        Slice k((char *)(indexes+i), sizeof(uint64_t));
        if(!NULDBDeleteValueForKey(db, writeOptions, k, error))
            return NO;
    }

    return YES;
}


// String values and keys
- (BOOL)storeStringsFromDictionary:(NSDictionary *)dictionary error:(NSError **)error {
 
    for(id key in [dictionary allKeys]) {

        Slice k = NULDBSliceFromString(key), v = NULDBSliceFromString([dictionary objectForKey:key]);
        
        if(!NULDBStoreValueForKey(db, writeOptions, k, v, error))
            return NO;
    }
    
    return YES;
}

- (NSDictionary *)storedStringsForKeys:(NSArray *)keys error:(NSError **)error {
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[keys count]];
    
    for(id key in keys) {
        
        NSString *result = nil;
        Slice k = NULDBSliceFromString(key);
        if(!NULDBLoadValueForKey(db, readOptions, k, &result, YES, error))
            if (4 == [*error code])
                continue;
            else
                return nil;

        [dictionary setObject:result forKey:key];
    }

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

- (BOOL)deleteStoredStringsForKeys:(NSArray *)keys error:(NSError **)error {
    
    for(id key in keys) {
        
        Slice k = NULDBSliceFromString(key);
        if(! NULDBDeleteValueForKey(db, writeOptions, k, error))
            return NO;
    }
    
    return YES;
}


#pragma mark Iteration
inline void NULDBIterateSlice(DB*db, Slice &start, Slice &limit, BOOL (^block)(Slice &key, Slice &value)) {
    
    ReadOptions readopts;
    const Comparator *comp = BytewiseComparator();
    
    readopts.fill_cache = false;
    
    Iterator*iter = db->NewIterator(readopts);
    
    for(iter->Seek(start); iter->Valid() && comp->Compare(limit, iter->key()); iter->Next()) {
        
        Slice key = iter->key(), value = iter->value();
        
        if(!block(key, value))
            return;
    }
    
    delete iter;
}

inline void NULDBIterateCoded(DB*db, Slice &start, Slice &limit, BOOL (^block)(id<NSCoding>, id<NSCoding>value)) {
    
    ReadOptions readopts;
    const Comparator *comp = BytewiseComparator();
    
    readopts.fill_cache = false;
    
    Iterator*iter = db->NewIterator(readopts);
    
    for(iter->Seek(start); iter->Valid() && comp->Compare(limit, iter->key()); iter->Next()) {
        
        Slice key = iter->key(), value = iter->value();
        
        if(!block(NULDBObjectFromSlice(key), NULDBObjectFromSlice(value)))
            return;
    }
    
    delete iter;
}

- (void)iterateFrom:(id<NSCoding>)start to:(id<NSCoding>)limit block:(BOOL (^)(id<NSCoding>key, id<NSCoding>value))block {
    Slice startSlice = NULDBSliceFromObject(start);
    Slice limitSlice = NULDBSliceFromObject(limit);
    NULDBIterateCoded(db, startSlice, limitSlice, block);
}

- (NSDictionary *)storedValuesFrom:(id<NSCoding>)start to:(id<NSCoding>)limit {
    
    NSMutableDictionary *tuples = [NSMutableDictionary dictionary];
    
    [self iterateFrom:start to:limit block:^(id<NSCoding>key, id<NSCoding>value) {
        [tuples setObject:value forKey:key];
        return YES;
    }];
    
    return tuples;
}

inline void NULDBIterateData(DB*db, Slice &start, Slice &limit, BOOL (^block)(NSData *key, NSData *value)) {
    
    
    ReadOptions readopts;
    const Comparator *comp = BytewiseComparator();
    
    readopts.fill_cache = false;
    
    Iterator*iter = db->NewIterator(readopts);
    
    for(iter->Seek(start); iter->Valid() && comp->Compare(limit, iter->key()); iter->Next()) {
        
        Slice key = iter->key(), value = iter->value();
        
        if(!block(NULDBDataFromSlice(key), NULDBDataFromSlice(value)))
            return;
    }
    
    delete iter;
}

- (void)iterateFromData:(NSData *)start toData:(NSData *)limit block:(BOOL (^)(NSData *key, NSData *value))block {
    Slice startSlice = NULDBSliceFromData(start);
    Slice limitSlice = NULDBSliceFromData(limit);
    NULDBIterateData(db, startSlice, limitSlice, block);
}

- (NSDictionary *)storedValuesFromData:(NSData *)start toData:(NSData *)limit {
    
    NSMutableDictionary *tuples = [NSMutableDictionary dictionary];

    [self iterateFromData:start toData:limit block:^(NSData *key, NSData *value) {
        [tuples setObject:value forKey:key];
        return YES;
    }];
    
    return tuples;
}

inline void NULDBIterateIndex(DB*db, Slice &start, Slice &limit, BOOL (^block)(uint64_t, NSData *value)) {
    
    ReadOptions readopts;
    const Comparator *comp = BytewiseComparator();
    
    readopts.fill_cache = false;
    
    Iterator*iter = db->NewIterator(readopts);
    
    for(iter->Seek(start); iter->Valid() && comp->Compare(limit, iter->key()); iter->Next()) {
        
        Slice key = iter->key(), value = iter->value();
        uint64_t index;
        memcpy(&index, key.data(), key.size());
        
        if(!block(index, NULDBDataFromSlice(value)))
            return;
    }
    
    delete iter;
}

- (void)iterateFromIndex:(uint64_t)start to:(uint64_t)limit block:(BOOL (^)(uint64_t key, NSData *value))block {
    Slice startSlice((char *)start, sizeof(uint64_t));
    Slice limitSlice((char *)limit, sizeof(uint64_t));
    NULDBIterateIndex(db, startSlice, limitSlice, block);
}

- (NSArray *)storedValuesFromIndex:(uint64_t)start to:(uint64_t)limit {
    
    NSMutableArray *array = [NSMutableArray array];
    
    [self iterateFromIndex:start to:limit block:^(uint64_t key, NSData *data) {
        [array addObject:data];
        return YES;
    }];
    
    return array;
}

@end
