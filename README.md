# NULevelDB

NULevelDB is an Objective-C wrapper for Google's C++ [leveldb](http://code.google.com/p/leveldb/) key-value store library. The wrapper API is straightforward. Most functionality is exposed by one class: **NULDBDB**.

For an introduction to leveldb and NULevelDB, see [Introducing NULevelDB for iOS](http://blog.nulayer.com/post/12790995102/introducing-nuleveldb-for-ios) at [the Nulayer Blog](http://blog.nulayer.com/).


## Installation

Once you've cloned the repository, open **NULevelDB.xcworkspace**, select the **NULevelDB** target, and hit build. (For release builds, choose **"Build for Profiling"** from the **"Product"** menu.) The result is a universal static framework which you can add to your project. Because it is universal, the same framework will work with the simulator and devices. The NULevelDB framework includes the leveldb static library, so you don't have to add that separately.

Modify your target settings to ensure proper linking. Under **"Build Phases>Link Binary With Libraries"**, add the C++ standard library (**libstdc++.dylib**) to your application target. Under **"Build Settings>Linking"**, add **"-all_load"** to **"Other Linker Flags"**.

To set up the framework as a dependency, create a "Vendor" folder in your main application project folder, and add two sub-folders: "Debug" and "Release". Put the debug and release builds of the framework into each of those folders, respectively. Add a path to your target under "Build Settings>Framework Search Paths" as "$(PROJECT_DIR)/Vendor/$(CONFIGURATION)", and Xcode will choose the right one based on your configuration. (Alternately, put the "Vendor" folder in your target sub-folder, if you have one, and use "$(SRC_ROOT)/Vendor/$(CONFIGURATION)", or whatever you prefer.)

Then add an import directive for NULDBDB to your source, like so:

    #import <NULevelDB/NULDBDB.h>

Instead of adding the built framework to your source, you can also add the **NULevelDB.xcodeproj** project file as a reference in your application project, add an entry under **Target > Build Phases > Dependencies"** and make sure that **NULevelDB.framework** is added to your target under **Target > Build Phases > Link Binary With Libraries"**.


## Basic Usage

You can create a new key-value store with **-initWithLocation:** or remove it with **+destroyDatabase:**.

leveldb supports saving key-value pairs. NULDBDB exposes this support with three basic methods:

    - (void)storeValue:(id<NSCoding>)value forKey:(id<NSCoding>)key;
    - (id)storedValueForKey:(id<NSCoding>)key;
    - (void)deleteStoredValueForKey:(id<NSCoding>)key;

There are also specialized interfaces for different types of objects, which will improve performance by using the best serialization method available.

For more info, please read the aforementioned blog post.


## Status

The core functionality is finished and stable. The embedded leveldb library is updated sporadically as major bug fixes are released by the leveldb developers.

There are a couple of experimental branches which you can safely ignore.

The most useful short-term feature improvement would be a finished NULDBIterator, since at the moment it's not possible to have multiple open cursors. Implementing other Objective-C wrapper classes depends on more use cases, but we haven't had the need for them in our products.


## Feedback and Pull Requests

If you would like to explore a new direction, please create a fork and have at it. If you can provide a new feature with unit tests and it extends the current API without modification, we'll integrate it into the main build. If you have questions about how to use the framework, or about the design, or just want to discuss ideas for changes to the API or other more radical improvements, feel free to message Brent Gulanowski (bgulanowski).

It would be cool to extend NULevelDB with a more fine-grained, even relational model, enough to support searching and filtering based on object properties (or even arbitrary key paths). I've thought about ways of doing this, but have not made significant progress. I wouldn't go so far as to re-create Core Data with leveldb, or even create a leveldb-based Core Data store, although either might be a great project for a senior or graduate student. Extended functionality of that sort should be implemented as a separate library, not in NULevelDB.


## License

BSD-style.

> Copyright (c) 2010, 2011, Nulayer, Inc.
> All rights reserved.
>
> Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
>
> Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
> Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
