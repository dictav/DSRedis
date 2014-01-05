//
//  Redis.m
//  CollaboQuest
//
//  Created by Abe Shintaro on 2013/06/28.
//  Copyright (c) 2013年 Abe Shintaro. All rights reserved.
//

#import "Redis.h"
#import "hiredis.h"

#ifndef Log
#define Log(__FORMAT__, ...) NSLog((@"%s [Line %d] " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#endif

@interface Redis ()
//@property (nonatomic) redisContext *context;
- (redisContext*)connectRedisServer:(NSString*)host port:(NSUInteger)port password:(NSString*)password;
@end

@implementation Redis
{
    //subscribe
    redisContext *_subscribeContext;
    NSString     *_subscribeKey;
}


static Redis *sharedRedis;
+ (Redis*)sharedRedis
{
    if (sharedRedis == nil) {
        @synchronized(self) {
            sharedRedis = [Redis new];
        }
    }
    return sharedRedis;
}

+ (void)setSharedRedis:(Redis *)redis
{
    sharedRedis = redis;
}

- (id)init
{
    return [self initWithServer:@"localhost" port:6379 password:nil];
}

- (id)initWithServer:(NSString*)host port:(NSUInteger)port password:(NSString*)password
{
    self = [super init];
    if (self) {
        _host = host;
        _port = port;
        _password = password;
        _subscribeContext = NULL;
        _subscribeKey = nil;
        
    }
    return self;
}


- (redisContext*)connectRedisServer:(NSString*)host port:(NSUInteger)port password:(NSString*)password
{
    redisContext *c = redisConnect([host UTF8String], port);
    if (c->err) {
        Log(@"ERROR!!!: %s", c->errstr);
        redisFree(c);
        return NULL;
    }
    
    // Auth
    if (c && password) {
        redisReply *auth = redisCommand(c, "AUTH %s", [password UTF8String]);
        if (auth->type == REDIS_REPLY_ERROR) {
            Log(@"ERROR: %s", auth->str);
            redisFree(c);
            c = NULL;
        }
        freeReplyObject(auth);
    }
    
    return c;
}

- (void)dealloc
{
    if ([sharedRedis isEqual:self]) {
        sharedRedis = nil;
    }
}

- (id)sendCommand:(NSString*)command key:(NSString*)key value:(id)value
{
    @synchronized(self) {
        id rtn;
        @try {
            rtn = [self concealSendCommand:command key:key value:value];
        }
        @catch (NSException *exception) {
            Log(@"redis send command error: %@\n command: %@\n key: %@\n value: %@", exception, command, key, value);
            rtn = nil;
        }
        @finally {
            return rtn;
        }
    }
}

- (id)concealSendCommand:(NSString*)command key:(NSString*)key value:(id)value
{
    // simulate network
    if ([_host isEqualToString:@"localhost"]) {
        [NSThread sleepForTimeInterval:0.3];
    }
    
    redisContext *context;
    context = [self connectRedisServer:_host port:_port password:_password];
    if (context == NULL) {
        Log(@"cannot connect redis server: %@", _host);
        return nil;
    }
    
    
    redisReply *reply;
    if ([value isKindOfClass:[NSString class]]) {
        reply = redisCommand(context, "%s %s %s",
                             [command UTF8String], [key UTF8String], [value UTF8String]);
        
    } else if ([value isKindOfClass:[NSData class]]) {
        reply = redisCommand(context, "%s %s %b",
                             [command UTF8String], [key UTF8String], [value bytes], [value length]);
        
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *argList = [@[command, key] arrayByAddingObjectsFromArray:value];
        int argc = argList.count;
        const char *argv[argc];
        size_t argvlen[argc];
        
        int c=0;
        for (id v in argList) {
            id val = v;
            // convert number to string
            if ([v isKindOfClass:[NSNumber class]]) {
                val = [v stringValue];
            }
            
            // set string or data to args
            if ([val isKindOfClass:[NSString class]]) {
                argv[c] = [val UTF8String];
                argvlen[c] = [val lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            } else if([val isKindOfClass:[NSData class]]){
                argv[c] = (const char *)[val bytes];
                argvlen[c] = [val length]; //\0
            } else {
                NSAssert(NO, @"ERROR class: %@", NSStringFromClass([val class]));
            }
            c++;
        }
        
        reply = redisCommandArgv(context, argc, argv, argvlen);
        
    } else if(key != nil) {
        reply = redisCommand(context, "%s %s",
                             [command UTF8String], [key UTF8String]);
    } else {
        reply = redisCommand(context, [command UTF8String]);
    }
    
    if (reply == NULL) {
        Log(@"could not coplemete command: %@ %@ %@", command, key, value);
        return nil;
    }
    
    if (reply->type == REDIS_REPLY_ERROR) {
        Log(@"ERROR!! %s, command:%@, key:%@, value:%@", reply->str, command,key,value);
    }
    
    id rtn;
    rtn = [self objectFromReply:reply];
    freeReplyObject(reply);
    redisFree(context);
    
    return rtn;
}

- (id)objectFromReply:(redisReply*)reply
{
    @synchronized (self){
        return [self concealObjectFromReply:reply];
    }
}

- (id)concealObjectFromReply:(redisReply*)reply
{
    id rtn = nil;
    NSData *data = [NSData dataWithBytes:reply->str length:reply->len];
    switch (reply->type) {
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_STATUS:
            rtn = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (rtn == nil) {
                rtn = data;
            }
            break;
            
        case REDIS_REPLY_INTEGER:
            rtn = @(reply->integer);
            break;
        case REDIS_REPLY_ARRAY:
            rtn = [NSMutableArray new];
            for (int n=0; n < reply->elements; n++) {
                [rtn addObject:[self objectFromReply:reply->element[n]]];
            }
            break;
        case REDIS_REPLY_NIL:
        case REDIS_REPLY_ERROR:
            break;
        default:
            break;
            
    }
    return rtn;
}

#pragma mark - COMMANDS
- (BOOL)ping
{
    return ([self sendCommand:@"ping" key:nil value:nil] != nil);
}

- (id)setValue:(id)value forKey:(NSString *)key
{
    NSAssert((key && value), @"require key and value");
    return [self sendCommand:@"set" key:key value:value];
}

- (id)setDictionary:(NSDictionary*)params forKey:(NSString *)key
{
    NSAssert((key && params && params.count), @"require key and value");
    NSMutableArray *vlist = [NSMutableArray new];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [vlist addObject:key];
        [vlist addObject:obj];
    }];
    return [self sendCommand:@"hmset" key:key value:vlist];
}

- (NSNumber*)pushValue:(id)stringOrData forKey:(NSString *)key
{
    NSAssert((key && stringOrData), @"require key and value");
    return [self sendCommand:@"rpush" key:key value:stringOrData];
}

- (id)setValue:(id)stringOrData forKey:(NSString *)key atIndex:(NSInteger)index
{
    NSAssert((key && stringOrData), @"require key and value");
    NSArray *vlist = @[
                       [@(index) stringValue],
                       stringOrData
                       ];
    return [self sendCommand:@"lset" key:key value:vlist];
}

- (id)addValue:(id)value forKey:(NSString*)key
{
    NSAssert((key && value), @"require key and value");
    return [self sendCommand:@"sadd" key:key value:value];
}

- (id)addValue:(id)value withScore:(NSNumber*)score forKey:(NSString*)key
{
    NSAssert((key && value && score), @"require key and value");
    return [self sendCommand:@"zadd" key:key value:value];
}
- (NSNumber*)incrementForKey:(NSString *)key
{
    NSAssert(key, @"require key");
    return [self sendCommand:@"incr" key:key value:nil];
}

- (NSArray*)allKeys:(NSString*)key
{
    return [self sendCommand:@"keys" key:key ? key : @"*" value:nil];
}

- (id)objectForKey:(NSString *)key
{
    NSAssert(key, @"require key");
    return [self sendCommand:@"get" key:key value:nil];
}

- (NSArray*)objectsForKey:(NSString *)key withRange:(NSRange)range
{
    NSAssert(key, @"require key");
    NSNumber *start = @(range.location);
    NSNumber *end = @(range.location + range.length -1);
    return [self sendCommand:@"lrange" key:key value:@[start,end]];
}

- (NSSet*)membersForKey:(NSString *)key
{
    NSAssert(key, @"require key");
    NSArray *members = [self sendCommand:@"smembers" key:key value:nil];
    return [NSSet setWithArray:members];
}

- (NSDictionary*)dictionaryForKey:(NSString *)key
{
    NSAssert(key, @"require key");
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSArray *array = [self sendCommand:@"hgetall" key:key value:nil];
    __block NSString *hkey;
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx%2 == 0) {
            hkey = obj;
        } else {
            dict[hkey] = obj;
        }
    }];
    
    return dict;
}

- (NSString*)uploadScript:(NSString *)script
{
    NSAssert(script, @"require script");
    return [self sendCommand:@"script" key:@"load" value:script];
}

- (id)evalWithSHA:(NSString*)sha keys:(NSArray*)keys args:(NSArray*)args
{
    NSAssert(sha, @"require sha");
    // make vlist
    NSArray *vlist;
    if (keys) {
        vlist = @[[@(keys.count) stringValue]];
        vlist = [vlist arrayByAddingObjectsFromArray:keys];
    } else {
        vlist = @[[@0 stringValue]];
    }
    if (args) {
        vlist = [vlist arrayByAddingObjectsFromArray:args];
    }
    return [self sendCommand:@"evalsha" key:sha value:vlist];
}

- (void)deleteObjectForKey:(NSString *)key
{
    [self sendCommand:@"del" key:key value:nil];
}

- (NSNumber*)setExpireDate:(NSDate *)date forKey:(NSString *)key
{
    NSAssert(date && key, @"require key and date");
    NSInteger timeInterval = date.timeIntervalSinceNow;
    NSString *value = [@(timeInterval) stringValue];
    return [self sendCommand:@"expire" key:key value:value];
}

- (void)publishValue:(id)stringOrData forKey:(NSString*)key
{
    NSAssert((key && stringOrData), @"require key and value");
    [self sendCommand:@"publish" key:key value:stringOrData];
}

- (void)subscribeForKey:(NSString*)key withBlock:(void (^)(id object))block
{
    // Prepare context
    if (_subscribeContext) {
        Log(@"already subscribing");
        return;
    }
    _subscribeContext = [self connectRedisServer:_host
                                           port:_port
                                       password:_password];
    if (_subscribeContext == NULL) {
        Log(@"cannot connect redis server: %@", _host);
        return;
    }
    
    
    _subscribeKey = key;
    NSString *command = [NSString stringWithFormat:@"SUBSCRIBE %@", _subscribeKey];
    
    redisReply *reply = redisCommand(_subscribeContext, [command UTF8String]);
    freeReplyObject(reply); // this is need
    while(redisGetReply(_subscribeContext, (void **)&reply) == REDIS_OK) {
        NSArray *rtn = [self objectFromReply:reply];
        block(rtn.lastObject);
        freeReplyObject(reply);
    }
}

- (void)unsubscribe;
{
    if (_subscribeContext ) {
        if ( _subscribeContext->flags | REDIS_CONNECTED) {
            @synchronized (self) {
                redisCommand(_subscribeContext, "UNSUBSCRIBE", [_subscribeKey UTF8String]);
                redisFree(_subscribeContext);
            }
        }
        _subscribeContext = NULL;
        _subscribeKey = nil;
    }
}

#pragma mark -
- (BOOL)hasKey:(NSString *)key
{
    assert(key);
    
    NSNumber *rtn = [self sendCommand:@"exists" key:key value:nil];
    return [rtn boolValue];
}

- (BOOL)hasMember:(id)object forKey:(NSString *)key
{
    assert(object);
    assert(key);
    
    NSNumber *rtn = [self sendCommand:@"sismember" key:key value:object];
    return [rtn boolValue];
}

- (BOOL)hasDictionaryKey:(NSString *)dictKey forKey:(NSString *)key
{
    assert(dictKey);
    assert(key);
    
    NSNumber *rtn = [self sendCommand:@"hexists" key:key value:dictKey];
    return [rtn boolValue];
}

@end
