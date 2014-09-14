//
//  Redis.m
//  CollaboQuest
//
//  Created by Abe Shintaro on 2013/06/28.
//  Copyright (c) 2013年 Abe Shintaro. All rights reserved.
//

#import "DSRedis.h"
#import "hiredis.h"

#ifndef Log
#define Log(__FORMAT__, ...) NSLog((@"%s [Line %d] " __FORMAT__), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#endif

@interface DSRedis ()
//@property (nonatomic) redisContext *context;
@property (nonatomic) dispatch_queue_t queue;
- (redisContext*)connectRedisServer:(NSString*)host port:(NSUInteger)port password:(NSString*)password;
@end

@implementation DSRedis
{
    //subscribe
    redisContext *_subscribeContext;
    NSString     *_subscribeKey;
}


static DSRedis *sharedRedis;
+ (DSRedis*)sharedRedis
{
    static dispatch_queue_t q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create("com.dictav.dsredis.shareinstance", NULL);
    });
    
    dispatch_sync(q, ^{
        sharedRedis = [DSRedis new];
    });
    
    return sharedRedis;
}

+ (void)setSharedRedis:(DSRedis *)redis
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
        _databaseNumber = @0;
        _queue = dispatch_queue_create("com.dictav.dsredis", NULL);
// TODO: Implent unsubscribe when the application is inactive
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(unsubscribe)
//                                                     name:UIApplicationDidEnterBackgroundNotification
//                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    if ([sharedRedis isEqual:self]) {
        sharedRedis = nil;
    }
}


- (redisContext*)connectRedisServer:(NSString*)host port:(NSUInteger)port password:(NSString*)password
{
    redisContext *c = redisConnect([host UTF8String], (int)port);
    if (c->err) {
        Log(@"ERROR could not connect server: %s", c->errstr);
        redisFree(c);
        return NULL;
    }
    
    // Auth
    if (c && password) {
        redisReply *auth = redisCommand(c, "AUTH %s", [password UTF8String]);
        if (auth) {
            if (auth->type == REDIS_REPLY_ERROR) {
                Log(@"ERROR could not auth: %s", auth->str);
                redisFree(c);
                c = NULL;
            }
            freeReplyObject(auth);
        }
    }
    
    return c;
}

- (id)sendCommand:(NSString*)command key:(NSString*)key value:(id)value
{
    __block id rtn;
    dispatch_sync(_queue, ^{
        rtn = [self trySendCommand:command key:key value:value];
    });
    
    return rtn;
}

- (id)trySendCommand:(NSString*)command key:(NSString*)key value:(id)value
{
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

- (id)concealSendCommand:(NSString*)command key:(NSString*)key value:(id)value
{
    // simulate network
#ifndef TEST
    if ([_host isEqualToString:@"localhost"]) {
        [NSThread sleepForTimeInterval:0.03];
    }
#endif
    
    redisContext *context;
    context = [self connectRedisServer:_host port:_port password:_password];
    if (context == NULL) {
        Log(@"cannot connect redis server: %@", _host);
        return nil;
    }
    
    
    redisReply *reply;
    if (![_databaseNumber isEqualToNumber:@0]) {
        redisCommand(context, "SELECT %d", _databaseNumber.integerValue);
    }
    if ([value isKindOfClass:[NSString class]]) {
        reply = redisCommand(context, "%s %s %s",
                             [command UTF8String], [key UTF8String], [value UTF8String]);
        
    } else if ([value isKindOfClass:[NSData class]]) {
        reply = redisCommand(context, "%s %s %b",
                             [command UTF8String], [key UTF8String], [value bytes], [value length]);
        
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *argList = [@[command, key] arrayByAddingObjectsFromArray:value];
        NSUInteger argc = argList.count;
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
        
        reply = redisCommandArgv(context, (int)argc, argv, argvlen);
        
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
        Log(@"ERROR %s, command:%@, key:%@, value:%@", reply->str, command,key,value);
    }
    
    id rtn;
    rtn = [self objectFromReply:reply];
    freeReplyObject(reply);
    redisFree(context);
    
    return rtn;
}

- (id)objectFromReply:(redisReply*)reply
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
                id obj = [self objectFromReply:reply->element[n]];
                if (obj == nil) {
                    obj = [NSNull null];
                }
                [rtn addObject:obj];
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
    return [self addValues:@[value] forKey:key];
}

- (id)addValues:(NSArray *)values forKey:(NSString *)key
{
    NSAssert((key && values && values.count > 0), @"require key and value");
    return [self sendCommand:@"sadd" key:key value:values];
}

- (id)addValue:(id)value withScore:(NSNumber*)score forKey:(NSString*)key
{
    NSAssert((key && value && score), @"require key and value");
    return [self sendCommand:@"zadd" key:key value:@[score, value]];
}
- (NSNumber*)incrementForKey:(NSString *)key
{
    NSAssert(key, @"require key");
    return [self sendCommand:@"incr" key:key value:nil];
}

- (NSNumber*)incrementObject:(id)stringOrData score:(NSNumber*)score forKey:(NSString*)key
{
    NSAssert(key && stringOrData, @"require key and object");
    if (score == nil) { score = @1; }
    id rtn = [self sendCommand:@"zincrby" key:key value:@[[score stringValue], stringOrData]];
    if (rtn) {
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];

        rtn = [f numberFromString:rtn];
    }
    return rtn;
}

- (NSNumber*)scoreForKey:(NSString *)key member:(NSString *)member
{
    NSAssert(key && member, @"require key and member");
    id rtn = [self sendCommand:@"zscore" key:key value:member];
    if (rtn) {
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        
        rtn = [f numberFromString:rtn];
    }
    return rtn;
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

// hget,hmget
- (NSDictionary*)dictionaryForKey:(NSString *)key subKeys:(NSArray *)subKeys
{
    NSAssert(key && subKeys && subKeys.count > 0, @"require key");
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSArray *array = [self sendCommand:@"hmget" key:key value:subKeys];
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dict[ subKeys[idx] ] = obj;
    }];
    
    return dict;
}

// hgetall
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

- (NSDictionary*)scoresForKey:(NSString *)key withRange:(NSRange)range
{
    NSAssert(key, @"require key");
    // get scores
    NSNumber *start = @(range.location);
    NSNumber *end = @(range.location + range.length -1);
    NSArray *scores = [self sendCommand:@"zrevrange" key:key value:@[start,end,@"withscores"]];
    
    // make dictionary
    NSMutableArray *keys = [NSMutableArray new];
    NSMutableArray *values = [NSMutableArray new];
    [scores enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        if (idx % 2 == 0) {
            [keys addObject:obj];
        }
        else {
            NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            [values addObject:[f numberFromString:obj]];
        }
    }];
    
    return [NSDictionary dictionaryWithObjects:values forKeys:keys];
}

#pragma mark -

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

#pragma mark - DELETE
// delete object
- (id)deleteObjectForKey:(NSString *)key
{
    NSAssert(key, @"require key");
    return [self sendCommand:@"del" key:key value:nil];
}

// srem
- (id)removeObject:(id)value forKey:(NSString*)key
{
    NSAssert(key && value, @"require key and value");
    return [self sendCommand:@"srem" key:key value:value];
}

// hdel
- (id)removeObjectForDictionaryKey:(NSString*)subKey forKey:(NSString*)key
{
    NSAssert(key && subKey, @"require key and subKey");
    return [self sendCommand:@"hdel" key:key value:subKey];
}

// zrem

#pragma mark -
- (BOOL)moveMember:(id)value fromKey:(NSString *)fromKey toKey:(NSString *)toKey
{
    NSAssert(value && fromKey && toKey, @"require keys and value");
    id rtn = [self sendCommand:@"smove" key:fromKey value:@[toKey,value]];
    return [rtn isEqualToNumber:@1];
}
#pragma mark -

- (NSNumber*)setExpireDate:(NSDate *)date forKey:(NSString *)key
{
    NSAssert(date && key, @"require key and date");
    NSInteger timeInterval = date.timeIntervalSinceNow;
    NSString *value = [@(timeInterval) stringValue];
    return [self sendCommand:@"expire" key:key value:value];
}

- (NSNumber*)publishValue:(id)stringOrData forKey:(NSString*)key
{
    NSAssert((key && stringOrData), @"require key and value");
    return [self sendCommand:@"publish" key:key value:stringOrData];
}
static BOOL isSubscribing = NO;
- (void)subscribeForKey:(NSString*)key withBlock:(void (^)(id object))block
{
    // Prepare context
    if (_subscribeContext != NULL) {
        isSubscribing = YES;
        if (_subscribeKey == nil) {
            _subscribeKey = key;
        }
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
    if (reply == NULL) {
        Log(@"Error cannot subscribe");
        return;
    }
    freeReplyObject(reply); // this is need
    
    isSubscribing = YES;
    while(_subscribeContext && isSubscribing
          && redisGetReply(_subscribeContext, (void **)&reply) == REDIS_OK) {
        __block NSArray *rtn;
        dispatch_sync(_queue, ^{
            rtn = [self objectFromReply:reply];
        });
        block(rtn.lastObject);
        freeReplyObject(reply);
    }
    Log(@"leave from subsribing loop");
    
    if (_subscribeContext != NULL) {
        Log(@"Send unsubscribe");
        reply = redisCommand(_subscribeContext, "UNSUBSCRIBE", [_subscribeKey UTF8String]);
        if (reply) {
            freeReplyObject(reply); // this is need
        }
        redisFree(_subscribeContext);
        _subscribeContext = NULL;
    }
    
    // finish
    _subscribeKey = nil;
}

- (void)unsubscribe
{
    if (isSubscribing == NO) {
        return;
    }
    
    isSubscribing = NO;
    if (_subscribeKey) {
        [self publishValue:@"" forKey:_subscribeKey];
    }
}

#pragma mark -
- (BOOL)hasKey:(NSString *)key
{
    NSAssert(key, @"Error key is nil");
    
    NSNumber *rtn = [self sendCommand:@"exists" key:key value:nil];
    return [rtn boolValue];
}

- (BOOL)hasMember:(id)object forKey:(NSString *)key
{
    NSAssert(object && key, @"Error key or objetct are nil: {key=%@,object=%@}", key, object);
    
    NSNumber *rtn = [self sendCommand:@"sismember" key:key value:object];
    return [rtn boolValue];
}

- (BOOL)hasDictionaryKey:(NSString *)dictKey forKey:(NSString *)key
{
    NSAssert(dictKey && key, @"Error key or dictKey are nil: {key=%@,dictKey=%@}", key, dictKey);
    
    NSNumber *rtn = [self sendCommand:@"hexists" key:key value:dictKey];
    return [rtn boolValue];
}

#pragma mark -
- (void)scanForKey:(NSString *)key type:(DSRedisType)type usingBlock:(void (^)(id, id, BOOL *))block
{
    [self scanForKey:key pattern:Nil type:type count:0 usingBlock:block];
}

- (void)scanForKey:(NSString *)key pattern:(NSString *)pattern type:(DSRedisType)type count:(NSInteger)count usingBlock:(void (^)(id, id, BOOL *))block
{
    // setup command
    NSString* cmd;
    NSMutableArray *params = [NSMutableArray new];
    if (key == nil) {
        cmd = @"scan";
        key = @"0";
    }
    else {
        switch ((NSInteger)type) {
            case DSRedisTypeHash:
                cmd = @"hscan";
                break;
            case DSRedisTypeSet:
                cmd = @"sscan";
                break;
            case DSRedisTypeScore:
                cmd = @"zscan";
                break;
            default:
                return;
        }
        [params addObject:@"0"];
    }
    
    if (pattern) {
        [params addObject:@"MATCH"];
        [params addObject:pattern];
    }
    
    if (count) {
        [params addObject:@"COUNT"];
        [params addObject:[@(count) stringValue]];
    }
    
    //
    __block BOOL scanStop = NO;
    while (!scanStop) {
        // scan command return array
        // example for scan and sscan)
        // ["32",
        //  [ obj1, obj2, obj3, ...] ]
        // example for hscan)
        // ["32",
        //  [ [idx1, obj1], [idx2, obj2], [idx3, obj3], ...] ]
        // example for zscan)
        // ["32",
        //  [ [obj1, score1], [obj2, score2], [obj3, score3], ...] ]
        
        NSArray *ret = [self sendCommand:cmd key:key value:params];
        if (ret == nil) {
            break;
        }
        // set next key
        key = ret.firstObject;
        
        // start scan
        NSEnumerator *enumrator = [ret.lastObject objectEnumerator];
        
        id obj1, obj2;
        do {
            obj1 = [enumrator nextObject];
            obj2 = [enumrator nextObject];
            switch (type) {
                case DSRedisTypeScore:
                case DSRedisTypeHash:
                    if (obj1 && obj2) { block(obj2, obj1, &scanStop); }
                    break;
                default:
                    if (obj1) { block(obj1, nil, &scanStop); }
                    if (obj2) { block(obj2, nil, &scanStop); }
                    break;
            }
            if (scanStop) {
                return;
            }
            
        } while (obj1 != nil);
        
        scanStop = [key isEqualToString:@"0"];
    }
    
}

// flushall
- (void)flushall
{
    [self sendCommand:@"flushall" key:nil value:nil];
}

@end
