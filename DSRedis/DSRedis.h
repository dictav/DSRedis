//
//  Redis.h
//  CollaboQuest
//
//  Created by Abe Shintaro on 2013/06/28.
//  Copyright (c) 2013年 Abe Shintaro. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef enum {
    DSRedisTypeNormal,
    DSRedisTypeList,
    DSRedisTypeSet,
    DSRedisTypeScore,
    DSRedisTypeHash
} DSRedisType;

@interface DSRedis : NSObject
@property (nonatomic, retain) NSString *host;
@property (nonatomic) NSUInteger port;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSNumber *databaseNumber;

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
// TODO: implement
// - (id)unshiftValue:(id)stringOrData forKey:(NSString *)key;

// lset
- (id)setValue:(id)stringOrData forKey:(NSString *)key atIndex:(NSInteger)index;

// sadd string value to Set
- (id)addValue:(id)stringOrData forKey:(NSString*)key;
- (id)addValues:(NSArray*)values forKey:(NSString*)key;

// zadd
- (id)addValue:(id)stringOrData withScore:(NSNumber*)score forKey:(NSString*)key;

// increment
- (NSNumber*)incrementForKey:(NSString*)key;

// zinc
- (NSNumber*)incrementObject:(id)stringOrData score:(NSNumber*)score forKey:(NSString*)key;

// zscore
- (NSNumber*)scoreForKey:(NSString*)key member:(NSString*)member;

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

// hget
// hmget
- (NSDictionary*)dictionaryForKey:(NSString*)key subKeys:(NSArray*)subKeys;

// hgetall
- (NSDictionary*)dictionaryForKey:(NSString*)key;

// zrange
- (NSDictionary*)scoresForKey:(NSString*)key withRange:(NSRange)range;
#pragma mark - Scan enumrations
// scan and sscan return only obj
// hscan return obj and idx as Index
// sscan return obj and idx as Score
- (void)scanForKey:(NSString*)key type:(DSRedisType)type usingBlock:(void (^)(id obj, id idx, BOOL *stop))block;
- (void)scanForKey:(NSString*)key pattern:(NSString*)pattern type:(DSRedisType)type count:(NSInteger)count usingBlock:(void (^)(id obj, id idx, BOOL *stop))block;

#pragma mark -
// exist
- (BOOL)hasKey:(NSString*)key;

// sismember
- (BOOL)hasMember:(id)object forKey:(NSString*)key;

// hexist
- (BOOL)hasDictionaryKey:(NSString*)dictKey forKey:(NSString*)key;

#pragma mark -
// delete object
- (id)deleteObjectForKey:(NSString*)key;

// srem
- (id)removeObject:(id)value forKey:(NSString*)key;

// hdel
- (id)removeObjectForDictionaryKey:(NSString*)subKey forKey:(NSString*)key;

// zrem

#pragma mark - move
// smove
- (BOOL)moveMember:(id)value fromKey:(NSString *)fromKey toKey:(NSString *)toKey;
#pragma mark -
// script load
- (NSString*)uploadScript:(NSString*)script;

// evalsha
- (id)evalWithSHA:(NSString*)sha keys:(NSArray*)keys args:(NSArray*)args;

#pragma mark -
// publish
- (NSNumber*)publishValue:(id)stringOrData forKey:(NSString*)key;

// subscribe
- (void)subscribeForKey:(NSString*)key withBlock:(void (^)(id object))block;

// unsubscribe
- (void)unsubscribe;


// FLUSHALL
- (void)flushall;
@end
