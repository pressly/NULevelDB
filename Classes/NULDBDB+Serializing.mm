//
//  NULDBDB+Serializing.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-11-04.
//  Copyright (c) 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBDB_private.h"


@interface NULDBDB (Serializing_private)

#if USE_INDEXED_SERIALIZATION
- (void)storeProperty:(id)property forKey:(PropertyKey)key;
- (id)propertyForKey:(PropertyKey)key;

- (ObjectKey)serializeObject:(id<NULDBSerializable>)object;
- (id)unserializeObjectForKey:(ObjectKey)key;

- (NSDictionary *)storeContentsOfDictionary:(NSDictionary *)dictionary name:(NSString *)name;
- (void)storeDictionary:(NSDictionary *)plist forKey:(PropertyKey)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)storedDict;

- (NSUInteger)arrayCodeForArrayKey:(ArrayKey)arrayKey;

- (ArrayKey)storeElementsInArray:(NSArray *)array objectCode:(NSUInteger)objectCode propertyIndex:(NSUInteger)propertyIndex;
- (void)storeArray:(NSArray *)array forKey:(PropertyKey)key;
- (NSArray *)unserializeArrayForKey:(ArrayKey)key;
- (void)deleteStoredArrayContentsForKey:(PropertyKey)key;

#else
- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj;

- (void)storeObject:(id)obj forKey:(NSString *)key;

- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key;
- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict;
- (void)deleteStoredDictionary:(NSDictionary *)storedDict;

- (void)storeArray:(NSArray *)array forKey:(NSString *)key;
- (NSArray *)unserializeArrayForKey:(NSString *)key;
- (void)deleteStoredArrayContentsForKey:(NSString *)key;
#endif

@end


@implementation NULDBDB (Serializing)

#define NULDBClassToken(_class_name_) ([NSString stringWithFormat:@"%@:NUClass", _class_name_])
#define NULDBIsClassToken(_key_) ([_key_ hasSuffix:@"NUClass"])
#define NULDBClassFromToken(_key_) ([_key_ substringToIndex:[_key_ rangeOfString:@":"].location])

#define NULDBPropertyKey(_class_name_, _prop_name_, _obj_key_ ) ([NSString stringWithFormat:@"%@:%@|%@:NUProperty", _prop_name_, _obj_key_, _class_name_])
#define NULDBIsPropertyKey(_key_) ([_key_ hasSuffix:@"NUProperty"])
#define NULDBPropertyIdentifierFromKey(_key_) ([_key_ substringToIndex:[_key_ rangeOfString:@"|"].location])

#define NULDBArrayToken(_array_, _count_) ([NSString stringWithFormat:@"%u:%@|NUArray", _count_, NSStringFromClass([[_array_ lastObject] class])])
#define NULDBIsArrayToken(_key_) ([_key_ hasSuffix:@"NUArray"])

#define NULDBArrayIndexKey(_key_, _index_) ([NSString stringWithFormat:@"%u:%@:NUIndex", _index_, _key_])
#define NULDBIsArrayIndexKey(_key_) ([_key_ hasSuffix:@"NUIndex"])
#define NULDBArrayCountFromKey(_key_) ([[_key_ substringToIndex:[_key_ rangeOfString:@":"].location] intValue])


#define NULDBWrappedObject(_object_) ([NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([_object_ class]), @"class", [_object_ plistRepresentation], @"object", nil])
#define NULDBUnwrappedObject(_dict_, _class_) ([[_class_ alloc] initWithPropertyList:[(NSDictionary *)_dict_ objectForKey:@"object"]])


static NSMutableDictionary *classProperties;

+ (void)load {
    classProperties = [[NSMutableDictionary alloc] initWithCapacity:100];
}


static inline NSString *NULDBClassFromPropertyKey(NSString *key) {
    
    NSString *classFragment = [key substringFromIndex:[key rangeOfString:@"|"].location+1];
    
    return [classFragment substringToIndex:[key rangeOfString:@":"].location];
}

static inline NSString *NULDBClassFromArrayToken(NSString *token) {
    
    NSString *fragment = [token substringToIndex:[token rangeOfString:@"|"].location];
    
    return [fragment substringFromIndex:[fragment rangeOfString:@":"].location+1];
}


- (id)unserializeObjectForClass:(NSString *)className key:(NSString *)key {
    
    NSArray *properties = [self storedValueForKey:NULDBClassToken(className)];
    
    if([properties count] < 1)
        return nil;
    
    
    id obj = [[NSClassFromString(className) alloc] init];
    
    
    NULDBLog(@" RESTORE %@", className);
    
    for(NSString *property in properties)
        [obj setValue:[self storedObjectForKey:NULDBPropertyKey(className, property, key)] forKey:property];
    
    return [obj autorelease];
}

#pragma mark Dictionaries
#if USE_INDEXED_SERIALIZATION
- (void)storeDictionary:(NSDictionary *)plist forKey:(PropertyKey)key {
    
    // Here's an unfortunate slowdown, but I need it to unique this dictionary
    // If there was a way to calculate a hash on the dict before storing it, we could at least prevent redundant writing
    NSString *name = nil;
    std::string tempValue;
    Status status = db->Get(readOptions, key.slice(), &tempValue);
    
    if(!status.IsNotFound()) {
        
        Slice slice = tempValue;
        
        name = [NULDBObjectFromSlice(slice) objectForKey:@"name"];
    }
    
    if(nil == name)
        name = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
    
    
    NSDictionary *namedDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               [self storeContentsOfDictionary:plist name:name], @"content",
                               name, @"name",
                               nil];
    
    status = db->Put(writeOptions, key.slice(), NULDBSliceFromObject(namedDict));
    assert(status.ok());
}

- (id)decodeDictionaryObject:(id)object {
    
    if([object isKindOfClass:[NSDictionary class]])
        return [self unserializeDictionary:object];
    
    if([object isKindOfClass:[NSData class]]) {
        
        // TODO: decode NSData-encoded StorageKeys
        // ... or am making this too complicated?
        id obj = nil;
        
        // TODO: FINISH
        if(0){
            
            PropertyKey *propertyKey;
            
            obj = [self propertyForKey:*propertyKey];
        }
        
        return NULDBDecodedObject(object);
        
    }
    
    return nil;
}

- (id)unserializeDictionary:(NSDictionary *)storedDict {
    
    Class objcClass = NSClassFromString([storedDict objectForKey:@"class"]);
    
    if([objcClass conformsToProtocol:@protocol(NULDBPlistTransformable)])
        return NULDBUnwrappedObject(storedDict, objcClass);
    
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:[storedDict count]];
    
    for(NSString *key in [storedDict allKeys])
        [dictionary setObject:[self decodeDictionaryObject:[storedDict objectForKey:key]] forKey:key];
    
    return dictionary;
}

- (void)deleteStoredDictionary:(NSDictionary *)storedDict {
    
    // TODO: Implement
}


#pragma mark Arrays
- (ArrayKey)storeElementsInArray:(NSArray *)array objectCode:(NSUInteger)objectCode propertyIndex:(NSUInteger)propertyIndex {
    
    ArrayKey arrayKey(' ', objectCode, propertyIndex); // Fix this - we don't have a vType anymore
    NSUInteger arrayCode = [self arrayCodeForArrayKey:arrayKey];
    
    // TODO: Implement
    int i=0;
    for(id item in array) {
        
        ArrayIndexKey indexKey(i++, arrayCode);
    }
    
    return arrayKey;
}

- (void)storeArray:(NSArray *)array forKey:(PropertyKey)key {
    
    ArrayKey arrayKey = [self storeElementsInArray:array objectCode:key.getObjectName() propertyIndex:key.getPropertyIndex()];
    Status status = db->Put(writeOptions, key.slice(), arrayKey.slice());
    
    assert(status.ok());
}

- (NSArray *)unserializeArrayForKey:(ArrayKey)key {
    
    // TODO: Implement
    return nil;
}

- (void)deleteStoredArrayContentsForKey:(PropertyKey)key {
    
    // TODO: Implement
}

#else
#pragma mark Generic Objects
- (NSString *)_storeObject:(NSObject<NULDBSerializable> *)obj {
    
    NSString *key = [obj storageKey];
    
    NSString *className = NSStringFromClass([obj class]);
    NSString *classKey = NULDBClassToken(className);
    NSArray *properties = [classProperties objectForKey:classKey];
    
    NSAssert1(nil != classKey, @"No key for class %@", className);
    NSAssert1(nil != key, @"No storage key for object %@", obj);
    
    NULDBLog(@" ARCHIVE %@", className);
    
    if(nil == properties) {
        properties = [obj propertyNames];         
        [self storeValue:properties forKey:classKey];
        [classProperties setObject:properties forKey:classKey];
    }
    
    [self storeValue:classKey forKey:key];
    
    for(NSString *property in properties)
        [self storeObject:[obj valueForKey:property] forKey:NULDBPropertyKey(className, property, key)];
    
    return key;
}

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

- (id)unserializeObjectForClass:(NSString *)className key:(NSString *)key {
    
    NSString *classKey = NULDBClassToken(className);
    NSArray *properties = [classProperties objectForKey:classKey];
    
    if(nil == properties)
        properties = [self storedValueForKey:classKey];
    
    if([properties count] < 1)
        return nil;
    
    
    id obj = [[NSClassFromString(className) alloc] init];
    
    
    NULDBLog(@" RESTORE %@", className);
    
    for(NSString *property in properties)
        [obj setValue:[self storedObjectForKey:NULDBPropertyKey(className, property, key)] forKey:property];
    
    return [obj autorelease];
}

#pragma mark Dictionaries
// Support for NULDBSerializable objects in the dictionary
- (void)storeDictionary:(NSDictionary *)plist forKey:(NSString *)key {
    
    NSMutableDictionary *lookup = [NSMutableDictionary dictionaryWithCapacity:[plist count]];
    
    for(id dictKey in [plist allKeys]) {
        
        @autoreleasepool {
            
            id value = [plist objectForKey:dictKey];
            
            // FIXME: this is lame, should always call the same wrapper
            if([value conformsToProtocol:@protocol(NULDBPlistTransformable)])
                value = [value plistRepresentation];
            else if([value conformsToProtocol:@protocol(NULDBSerializable)])
                value = [self _storeObject:value]; // store the object and replace it with it's lookup key
            
            [lookup setObject:value forKey:dictKey];
        }
    }
    
    [self storeValue:lookup forKey:key];
}

- (NSDictionary *)unserializeDictionary:(NSDictionary *)storedDict {
    
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[storedDict count]];
    
    for(NSString *key in [storedDict allKeys]) {
        
        @autoreleasepool {
            id value = [self storedObjectForKey:key];
            
            if(value)
                [result setObject:value forKey:key];
            else
                [result setObject:[storedDict objectForKey:key] forKey:key];
        }
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
    
    [self storeValue:NULDBArrayToken(array, [array count]) forKey:key];
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


#pragma mark - Public Interface
- (void)storeObject:(NSObject<NULDBSerializable> *)obj {
#if USE_INDEXED_SERIALIZATION
    
#else
    [self _storeObject:obj];
#endif
}

- (id)storedObjectForKey:(NSString *)key {
    
#if USE_INDEXED_SERIALIZATION
    return nil;
#else
    id storedObj = [self storedValueForKey:key];
    
    // the key is a property key but we don't really care about that; we just need to reconstruct the dictionary
    if([storedObj isKindOfClass:[NSDictionary class]] && (NULDBIsPropertyKey(key) || NULDBIsArrayIndexKey(key))) {
        
        Class propClass = NSClassFromString([storedObj objectForKey:@"class"]);
        
        if([propClass conformsToProtocol:@protocol(NULDBPlistTransformable)])
            return [[[propClass alloc] initWithPropertyList:[storedObj objectForKey:@"object"]] autorelease];
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
    
#if USE_INDEXED_SERIALIZATION
    
    
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


#pragma mark - Private Relationship Support

#if USE_INDEXED_SERIALIZATION
#pragma mark Entity Indexing
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
        
        // save the class token under the classname key
        status = db->Put(writeOptions, className.slice(), classKey->slice());
        assert(status.ok());
        
        [self saveCounters];
        
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

- (NSUInteger)objectCodeForObject:(id)object storageKey:(NSString *)storageKey {
    
    NSUInteger result = 0;
    std::string value;
    
    StringKey key = StringKey(storageKey);
    Status status = db->Get(readOptions, key.slice(), &value);
    ObjectKey *objectKey;
    
    if(status.IsNotFound()) {
        
        // add a token for the object - don't store the object key until we store the object itself
        
        // update the counters
        objectKey = new ObjectKey(counters->addObject(), [self classCodeForObject:object]);
        
        status = db->Put(writeOptions, key.slice(), objectKey->slice());
        assert(status.ok());
        
        [self saveCounters];
        
        result = objectKey->getName();
    }
    else {
        assert(status.ok());
        Slice slice = value;
        objectKey = new ObjectKey(slice);
    }
    
    result = objectKey->getName();
    
    delete objectKey;
    
    return result;
}

- (NSUInteger)objectCodeForSerializableObject:(id<NULDBSerializable>)object {
    return [self objectCodeForObject:object storageKey:[object storageKey]];
}

- (NSUInteger)objectCodeForDictionary:(NSDictionary *)dict name:(NSString *)name {
    return [self objectCodeForObject:dict storageKey:name];
}

- (NSUInteger)arrayCodeForArrayKey:(ArrayKey)arrayKey {
    
    NSUInteger result;
    std::string tempValue;
    Status status = db->Get(readOptions, arrayKey.slice(), &tempValue);
    ArrayToken *token;
    
    if(status.IsNotFound()) {
        
        token = new ArrayToken(counters->addArray());
        
        status = db->Put(writeOptions, arrayKey.slice(), token->slice());
        
        [self saveCounters];
    }
    else {
        assert(status.ok());
        Slice slice = tempValue;
        token = new ArrayToken(slice);
    }
    
    result = token->getName();
    
    delete token;
    
    return result;
}


#pragma mark Property Transcoding
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
            return NULDBDecodedObject(NULDBObjectFromSlice(slice));
            break;
            
        default:
            break;
    }
    
    return nil;
}

// Returns the unique object storage key
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
    
    return object;
}

- (NSDictionary *)storeContentsOfDictionary:(NSDictionary *)dictionary name:(NSString *)name {
    
    // replace serializable or plist transformable objects in dictionary with stored representations
    // for each serializable object, serialize it; store the property key in the new dictionary
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
    NSUInteger objectCode = [self objectCodeForDictionary:dictionary name:name];
    
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
            if([obj count]) {
                obj = [self storeElementsInArray:obj objectCode:objectCode propertyIndex:i].to_data();
            }
        }
        else if([obj isKindOfClass:[NSSet class]]) {
            if([obj count]) {
                obj = [self storeElementsInArray:[obj allObjects] objectCode:objectCode propertyIndex:i].to_data();
            }
        }
        else if([obj isKindOfClass:[NSDictionary class]]) {
            if([obj count]) {
                
                PropertyKey propertyKey(i, objectCode);
                
                [self storeDictionary:obj forKey:propertyKey];
                obj = propertyKey.to_data();
            }
        }
        
        [newDict setObject:NULDBEncodedObject(obj) forKey:key];
        
        ++i;
    }
    
    return newDict;
}

#endif

@end
