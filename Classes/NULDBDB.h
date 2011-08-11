//
//  NULDBDB.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-07-29.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <NULevelDB/NULDBSerializable.h>


@interface NULDBDB : NSObject

@property (retain) NSString *location;

- (id)initWithLocation:(NSString *)path;

// Erases the database files (files are created automatically)
- (void)destroy;

// works like a stack (counter); feel free to use indiscriminately
+ (void)enableLogging;
+ (void)disableLogging;

// User Library folder "Store.db"
+ (NSString *)defaultLocation;

// Basic key-value support
- (void)storeValue:(id<NSCoding>)value forKey:(id<NSCoding>)key;
- (id)storedValueForKey:(id<NSCoding>)key;
- (void)deleteStoredValueForKey:(id<NSCoding>)key;

//// Streamlined key-value support for pre-encoded Data objects
// Data keys
- (void)storeData:(NSData *)data forDataKey:(NSData *)key error:(NSError **)error;
- (NSData *)storedDataForDataKey:(NSData *)key error:(NSError **)error;
- (void)deleteStoredDataForDataKey:(NSData *)key error:(NSError **)error;

// String keys - string<->data conversion provided by client
// This will allow the client to replace string keys with optimized data keys of its own preference
- (void)storeData:(NSData *)data forKey:(NSString *)key translator:(NSData *(^)(NSString *))block error:(NSError **)error;
- (NSData *)storedDataForKey:(NSString *)key translator:(NSData *(^)(NSString *))block error:(NSError **)error;
- (void)deleteStoredDataForKey:(NSString *)key translator:(NSData *(^)(NSString *))block error:(NSError **)error;

// String keys - encoded as-is (UTF8 data)
- (void)storeData:(NSData *)data forKey:(NSString *)key error:(NSError **)error;
- (NSData *)storedDataForKey:(NSString *)key error:(NSError **)error;
- (void)deleteStoredDataForKey:(NSString *)key error:(NSError **)error;


// Object graph serialization support
// Arrays and dictionaries are handled automatically; sets are converted into arrays
- (void)storeObject:(NSObject<NULDBSerializable> *)obj;
- (id)storedObjectForKey:(NSString *)key;
- (void)deleteStoredObjectForKey:(NSString *)key;

// Iteration and search
- (void)iterateWithStart:(NSString *)start limit:(NSString *)limit block:(BOOL (^)(NSString *key, id<NSCoding>value))block;

- (NSDictionary *)storedValuesFromStart:(NSString *)start toLimit:(NSString *)limit;

@end
