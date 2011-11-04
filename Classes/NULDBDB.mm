//
//  NULDBDB.m
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import "NULDBDB.h"

#import "NULDBUtilities.h"
#import "NULDBDB_private.h"


int logging = 0;


static NSUInteger defaultBufferSize = 1<<22; // 1024 * 1024 * 4 => 4MB


void NULDBIterateSlice(DB*db, Slice &start, Slice &limit, BOOL (^block)(Slice &key, Slice &value));
void NULDBIterateCoded(DB*db, Slice &start, Slice &limit, BOOL (^block)(id<NSCoding>, id<NSCoding>value));
void NULDBIterateKeys(DB*db, Slice &start, Slice &limit, BOOL (^block)(NSString *key, NSData *value));
void NULDBIterateData(DB*db, Slice &start, Slice &limit, BOOL (^block)(NSData *key, NSData *value));
void NULDBIterateIndex(DB*db, Slice &start, Slice &limit, BOOL (^block)(uint64_t, NSData *value));


using namespace leveldb;


@interface NULDBDB ()

@property DB *db;
@property BOOL compacting;

@end


#pragma mark -
@implementation NULDBDB

@synthesize db, location, compacting;


NSString *NULDBErrorDomain = @"NULevelDBErrorDomain";


#pragma mark - NSObject
+ (void)initialize {
    stringClass = [NSString class];
    dataClass = [NSData class];
    dictClass = [NSDictionary class];
}

- (id)init {
    return [self initWithLocation:[NULDBDB defaultLocation] bufferSize:defaultBufferSize];
}

- (void)finalize {
#if USE_INDEXED_SERIALIZATION
    delete counters;
#endif
    self.db = NULL;
    delete classIndexKey;
    self.location = nil;
    [super finalize];
}


#pragma mark - Accessors
- (void)setDb:(DB *)newDB {
    @synchronized(self) {
        if(NULL != db) delete db;
        db = newDB;
    }
}

- (DB *)db {
    DB *result = NULL;
    @synchronized(self) {
        result = db;
    }
    return result;
}

- (void)setSync:(BOOL)flag {
    writeOptions.sync = flag;
}

- (BOOL)sync {
    return writeOptions.sync;
}

- (void)setCacheEnabled:(BOOL)flag {
    readOptions.fill_cache = flag;
}

- (BOOL)isCacheEnabled {
    return readOptions.fill_cache;
}


#pragma mark - NULDBDB
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

+ (void)destroyDatabase:(NSString *)path {
    Options options;
    leveldb::DestroyDB([path UTF8String], options);
}

- (BOOL)NU_openDatabase {
    
    Options options;
    options.create_if_missing = true;
    options.write_buffer_size = bufferSize;

    DB *theDB;
    
    Status status = DB::Open(options, [self.location UTF8String], &theDB);
        
    if(!status.ok())
        NSLog(@"Problem creating LevelDB database: %s", status.ToString().c_str());
    else
        self.db = theDB;
    
    return status.ok();
}

- (id)initWithLocation:(NSString *)path bufferSize:(NSUInteger)size {
    
    self = [super init];
    if (self) {
        
        self.location = path;
        bufferSize = size;
        
        if(![self NU_openDatabase]) {
            [self release];
            self = nil;
        }
        else {
            readOptions.fill_cache = false;
            writeOptions.sync = false;
            classIndexKey = new Slice("NULClassIndex");

            if(![self checkCounters]) [self saveCounters];
        }
    }
    
    return self;
}

- (id)initWithLocation:(NSString *)path {
    return [self initWithLocation:path bufferSize:defaultBufferSize];
}

- (void)destroy {
    Options options;
    self.db = NULL;
    [[self class] destroyDatabase:self.location];
}

- (void)compact {
    
    if(self.compacting) return;
    
    self.compacting = YES;
    
    db->CompactRange(NULL, NULL);
    
    self.compacting = NO;
}

- (void)reopen {
    // The existing database object MUST be removed/closed before a new one is created
    self.db = nil;
    [self NU_openDatabase];
}


#pragma mark - ErrorConstructing
+ (NSError *)errorForStatus:(Status *)status {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSString stringWithUTF8String:status->ToString().c_str()], NSLocalizedDescriptionKey,
//                              NSLocalizedString(@"", @""), NSLocalizedRecoverySuggestionErrorKey,
                              nil];
    return [NSError errorWithDomain:NULDBErrorDomain code:1 userInfo:userInfo];
}


#pragma mark - Generic NSCoding Access
- (BOOL)storeValue:(id<NSCoding>)value forKey:(id<NSCoding>)key {
    Slice k = NULDBSliceFromObject(key);
    Slice v = NULDBSliceFromObject(value);
    return NULDBStoreValueForKey(db, writeOptions, k, v, NULL);
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

- (BOOL)storedValueExistsForSlice:(Slice)slice {

    // Find the next key after the one provided (there is always at least one more key, the terminator)
    Iterator *iter = db->NewIterator(readOptions);
    iter->Seek(slice);

    BOOL result = iter->Valid() && BytewiseComparator()->Compare(slice, iter->key()) == 0;
    
    delete iter;
    
    return result;
}

- (BOOL)storedValueExistsForKey:(id<NSCoding>)key {
    return [self storedValueExistsForSlice:NULDBSliceFromObject(key)];
}


#pragma mark - Streamlined Access Interfaces

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

- (BOOL)storedDataExistsForDataKey:(NSData *)key {
    return [self storedValueExistsForSlice:NULDBSliceFromData(key)];
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

- (BOOL)storedDataExistsForKey:(NSString *)key {
    return [self storedValueExistsForSlice:NULDBSliceFromString(key)];
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

- (BOOL)storedStringExistsForKey:(NSString *)key {
    return [self storedValueExistsForSlice:NULDBSliceFromString(key)];
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

- (BOOL)storedDataExistsForIndexKey:(uint64_t)key {
    Slice k((char *)&key, sizeof(uint64_t));
    return [self storedValueExistsForSlice:k];
}

@end


#pragma mark -
@implementation NULDBDB (Deprecated)
- (void)iterateFrom:(id<NSCoding>)start to:(id<NSCoding>)limit block:(BOOL (^)(id<NSCoding>key, id<NSCoding>value))block {
    [self enumerateFrom:start to:limit block:block];
}
- (void)iterateFromKey:(NSString *)start toKey:(NSString *)limit block:(BOOL (^)(NSString *key, NSData *value))block {
    [self enumerateFromKey:start toKey:limit block:block];
}
- (void)iterateFromData:(NSData *)start toData:(NSData *)limit block:(BOOL (^)(NSData *key, NSData *value))block {
    [self enumerateFromData:start toData:limit block:block];
}
- (void)iterateFromIndex:(uint64_t)start to:(uint64_t)limit block:(BOOL (^)(uint64_t key, NSData *value))block {
    [self enumerateFromIndex:start to:limit block:block];
}
@end
