//
//  NULDBStorageKey.h
//  NULevelDB
//
//  Created by Brent Gulanowski on 11-08-10.
//  Copyright 2011 Nulayer Inc. All rights reserved.
//

#ifndef NULevelDB_NULDBStorageKey_h
#define NULevelDB_NULDBStorageKey_h


#include <leveldb/db.h>
#include <leveldb/slice.h>

#import "NULDBSerializable.h"


@class NULDBDB;


using namespace leveldb;

namespace NULDB {
    
    /*
     
     Here is a BNF-style notation which describes the Storage Key object types:
    
     objectName:    stringKey => objectKey
         string is the storageKey provided by objects that conform to NULDBSerializable
     
     objectKey:     ('N', 'U', 'O', ' ', c#, o#) => objectName
     
     arrayToken:    (vc, a#, count)
         vc is the type code of the property value ('s'-string, 'd'-data, 'h'-hash aka dictionary, or 'o'-object)
         a# is the unique integer assigned to the array
         count is the number of objects in the array
     
     arrayIndexKey: ('N', 'U', 'I', ' ', a#, i#) => propertyValue
         a# is the unique integer assigned to the array
         i# in the non-unique index of the value in the array
     
     propertyKey:   ('N', 'U', 'P', ' ', p#, o#) => propertyValue
         p# is the index to the property in the property names list
         o# is the unique integer assigned to the owning object

     propertyValue: string | number | archive | plist | objectKey | arrayToken
     
     className:     stringKey => classKey

     classKey:      ('N', 'U', 'C', ' ', c#, v#) => classDescription
         c# is from the classToken
         v# is reserved
          
     stringKey:     ("NULDB:"+string)
     
     classDescription: ("className", propertyNamesList)
     propertyNamesList: ("property1", '|', "property2", '|' ..., '|', "propertyN")
     
     */
        
    class StorageKey {
        
    public:
        
        static const char keyTypes[];
                
        StorageKey() : prefix1('N'), prefix2('U') {}
        
        StorageKey(char kType, char vType) : prefix1('N'), prefix2('U') {
            keyType = kType;
            valType = vType;
        }
        
        StorageKey(Slice &slice);
        
        static BOOL valid(Slice *slice);
        
        Slice slice( void ) {
            return Slice((const char*)this, sizeof(*this));
        }
        
        NSUInteger getName1() { return a; }
        NSUInteger getName2() { return b; }
        
    protected:
        const char prefix1;
        const char prefix2;
        char keyType;
        char valType;
        NSUInteger a;
        NSUInteger b;
    };
        
    
    class ObjectKey : public StorageKey {
        
    public:
        
        ObjectKey(NSUInteger classCode, NSUInteger objectCode) : StorageKey('O', ' ') {
            a = classCode;
            b = objectCode;
        }
        
        ObjectKey(Slice &slice) : StorageKey(slice) {};
        
        ObjectKey(NULDBDB *db, id object);
        
        NSUInteger getClassName() { return a; }
        NSUInteger getName() { return b; }
    };
    
    
    class ArrayToken {
        
    public:
        
        ArrayToken(char pType, NSUInteger index, NSUInteger arrayCount) {
            type = pType;
            name = index;
            count = arrayCount;
        }
        
        char getType() { return type; }
        NSUInteger getName() { return  name; }
        NSUInteger getCount() { return count; }
        
    private:
        
        char type;
        NSUInteger name;
        NSUInteger count;
    };
    
    
    class ArrayIndexKey : public StorageKey {
        
    public:
        
        ArrayIndexKey(NSUInteger index, NSUInteger arrayCode) : StorageKey('I', ' ') {
            a = arrayCode;
            b = index;
        }
        
        NSUInteger getArrayName() { return a; }
        NSUInteger getIndex() { return b; }
    };
    
    class PropertyKey : public StorageKey {
        
    public:    
        
        PropertyKey(NSUInteger propertyIndex, NSUInteger objectCode) : StorageKey('P', ' ') {
            a = propertyIndex;
            b = objectCode;
        }
        
        PropertyKey(Slice &slice) : StorageKey(slice) {}

        NSUInteger getPropertyIndex() { return a; }
        NSUInteger getObjectName() { return  b; }
    };
    
    
    class ClassKey : public StorageKey {
        
    public:
        
        // member "b" is not used
        
        ClassKey(NSUInteger classCode) : StorageKey('C', ' ') {
            a = classCode;
        }
        
        ClassKey(Slice &slice) : StorageKey(slice) {}
        
        ClassKey(NULDBDB *db, id object);
        
        NSUInteger getName() { return a; }
    };
    
    
    class ClassDescription {
        
    public:
        
        ClassDescription(id<NULDBSerializable> object) {
            className = NSStringFromClass([object class]);
            properties = [object propertyNames];
        }
        
        ClassDescription(Slice &slice);
        
        Slice slice();
        
    private:
        NSString *className;
        NSArray *properties;
    };
    
    
    class StringKey {
        
    public:
                
        StringKey(NSString *storageKey) {
            for(int i=0; i<6; ++i)
                prefix[i] = PREFIX[i];
            key = storageKey;
        }
        
        StringKey(Slice &slice) {
            memcpy(this, slice.data(), 6*sizeof(char));
            for(int i=0; i<6; ++i)
                assert(prefix[i] == PREFIX[i]);            
        }
        
        Slice slice() {
            
            NSMutableData *d = [NSMutableData dataWithBytes:PREFIX length:6*sizeof(char)];
            
            [d appendData:[key dataUsingEncoding:NSUTF8StringEncoding]];
            
            return Slice((const char *)[d bytes], [d length]);
        }
        
    private:
        static const char PREFIX[6];
        char prefix[6];
        NSString *key;
    };
    
    
    extern const Slice CountersKey;
    
    class Counters {
        
    public:
        
        Counters() {
            classes = 0;
            objects = 0;
            arrays = 0;
        }
        
        Counters(Slice &slice) {
            memcpy(this, &slice, sizeof(*this));
        }
        
        Slice slice(void) {
            return Slice((const char *)this, sizeof(*this));
        }
        
        NSUInteger addClass( void ) { return ++classes; }
        NSUInteger addObject( void ) { return ++objects; }
        NSUInteger addArray( void ) { return ++arrays; }
        
    private:
        
        NSUInteger classes;
        NSUInteger objects;
        NSUInteger arrays;
        
    };
}

#endif
