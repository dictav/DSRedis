//
//  Redis.h
//  CollaboQuest
//
//  Created by Abe Shintaro on 2013/06/28.
//  Copyright (c) 2013年 Abe Shintaro. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DSRedis : NSObject
@property (nonatomic, retain) NSString *host;
@property (nonatomic) NSUInteger port;
@property (nonatomic, retain) NSString *password;

+ (DSRedis*)sharedRedis;
+ (void)setSharedRedis:(DSRedis*)redis;

// initialize
- (id)initWithServer:(NSString*)host port:(NSUInteger)port password:(NSString*)password;

// ping
- (BOOL)ping;

// set
- (id)setValue:(id)stringOrData forKey:(NSString *)key;

// hset
- (id)setDictionary:(NSDictionary*)params forKey:(NSString *)key;

// rpush
- (NSNumber*)pushValue:(id)stringOrData forKey:(NSString *)key;

// lpush
- (id)unshiftValue:(id)stringOrData forKey:(NSString *)key;

// lset
- (id)setValue:(id)stringOrData forKey:(NSString *)key atIndex:(NSInteger)index;

// sadd string value to Set
- (id)addValue:(id)stringOrData forKey:(NSString*)key;

// zadd
- (id)addValue:(id)stringOrData withScore:(NSNumber*)score forKey:(NSString*)key;

// increment
- (NSNumber*)incrementForKey:(NSString*)key;

// zinc
- (NSNumber*)incrementObject:(id)stringOrData score:(NSNumber*)score forKey:(NSString*)key;

// expire
- (NSNumber*)setExpireDate:(NSDate*)date forKey:(NSString*)key;

// get keys
- (NSArray*)allKeys:(NSString*)key;

// get
- (id)objectForKey:(NSString*)key;

// lrange
- (NSArray*)objectsForKey:(NSString*)key withRange:(NSRange)range;

// smembers
- (NSSet*)membersForKey:(NSString*)key;

// hgetall
- (NSDictionary*)dictionaryForKey:(NSString*)key;

#pragma mark -
// exist
- (BOOL)hasKey:(NSString*)key;

// sismember
- (BOOL)hasMember:(id)object forKey:(NSString*)key;

// hexist
- (BOOL)hasDictionaryKey:(NSString*)dictKey forKey:(NSString*)key;

#pragma mark -
// delete object
- (void)deleteObjectForKey:(NSString*)key;

// script load
- (NSString*)uploadScript:(NSString*)script;

// evalsha
- (id)evalWithSHA:(NSString*)sha keys:(NSArray*)keys args:(NSArray*)args;

#pragma mark -
// publish
- (void)publishValue:(id)stringOrData forKey:(NSString*)key;

// subscribe
- (void)subscribeForKey:(NSString*)key withBlock:(void (^)(id object))block;

// unsubscribe
- (void)unsubscribe;
@end
