//
//  RedisTests.m
//  NatsuKoi
//
//  Created by Shintaro Abe on 1/27/14.
//  Copyright (c) 2014 dictav. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSRedis.h"

@interface RedisTests : XCTestCase

@end

@implementation RedisTests

static DSRedis *redis;
+ (void)setUp
{
    redis = [DSRedis new];
    if (![redis.host isEqualToString:@"localhost"]) {
        abort();
    }
}

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    [redis flushall];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testSelectDatabase
{
    [redis setValue:@"1" forKey:@"hoge"];
    XCTAssertNotNil([redis objectForKey:@"hoge"]);
    
    redis.databaseNumber = @1;
    XCTAssertNil([redis objectForKey:@"hoge"]);
}

- (void)testScan
{
    // prepare values
    [redis deleteObjectForKey:@"hoge_set"];
    [redis deleteObjectForKey:@"hoge_score"];
    [redis deleteObjectForKey:@"hoge_hash"];
    
    // set 100 values
    for (int n=0; n < 100; n++) {
        NSString *val = [@(n) stringValue];
        // for scan
        [redis setValue:val forKey:[@"hoge" stringByAppendingString:val]];
        
        // for sscan
        [redis addValue:val forKey:@"hoge_set"];
        
        // for zscan
        [redis addValue:val withScore:@(rand()) forKey:@"hoge_score"];
        
        // for hscan
        [redis setDictionary:@{val: @0} forKey:@"hoge_hash"];
    }
    
    __block NSInteger objCount = 0;
    __block NSInteger idxCount = 0;
    // scan
    [redis scanForKey:nil type:DSRedisTypeNormal usingBlock:^(id obj, id idx, BOOL *stop) {
        if (obj) { objCount++; }
        if (idx) { idxCount++; }
    }];
    XCTAssertEqual(objCount, 103); // contains hoge_set, hoge_score and hoge_hash
    XCTAssertEqual(idxCount, 0);
    
    // sscan
    objCount = idxCount = 0;
    [redis scanForKey:@"hoge_set" type:DSRedisTypeSet usingBlock:^(id obj, id idx, BOOL *stop) {
        if (obj) { objCount++; }
        if (idx) { idxCount++; }
    }];
    XCTAssertEqual(objCount, 100);
    XCTAssertEqual(idxCount, 0);
    
    // zscan
    objCount = idxCount = 0;
    [redis scanForKey:@"hoge_score" type:DSRedisTypeScore usingBlock:^(id obj, id idx, BOOL *stop) {
        if (obj) { objCount++; }
        if (idx) { idxCount++; }
    }];
    XCTAssertEqual(objCount, 100);
    XCTAssertEqual(idxCount, 100);
    
    // hscan
    objCount = idxCount = 0;
    [redis scanForKey:@"hoge_hash" type:DSRedisTypeHash usingBlock:^(id obj, id idx, BOOL *stop) {
        if (obj) { objCount++; }
        if (idx) { idxCount++; }
    }];
    XCTAssertEqual(objCount, 100);
    XCTAssertEqual(idxCount, 100);
}

- (void)testScanWithPattern
{
    
}

- (void)testScanWithCount
{
    
}

- (void)testHMGET
{
    
    // prepare values
    [redis deleteObjectForKey:@"hoge_hash"];
    NSMutableArray *keys = [NSMutableArray new];
    NSInteger keyNum = 100;
    for (int n = 0; n < keyNum; n++) {
        NSString *k = [@(n) stringValue];
        [redis setDictionary:@{k:[@"val for " stringByAppendingString:k]} forKey:@"hoge_hash"];
        [keys addObject:k];
    }
    XCTAssertTrue(keys.count == keyNum);
    
    NSInteger count = [redis dictionaryForKey:@"hoge_hash"].count;
    
    XCTAssertEqual(count, keyNum);
    
    count = [redis dictionaryForKey:@"hoge_hash" subKeys:keys].count;
    XCTAssertEqual(count, keyNum);
    
    NSArray *subKeys = [keys subarrayWithRange:NSMakeRange(0, 30)];
    count = [redis dictionaryForKey:@"hoge_hash" subKeys:subKeys].count;
    XCTAssertEqual(count, 30);
    
}

- (void)testHMGETContainsNil
{
    
    [redis deleteObjectForKey:@"hoge"];
    [redis setDictionary:@{@"a":@1, @"b":@2, @"c":@3} forKey:@"hoge"];
    NSInteger count = [[redis dictionaryForKey:@"hoge"] count];
    XCTAssertEqual(count, (NSInteger)3);
    
    NSDictionary *dict = [redis dictionaryForKey:@"hoge" subKeys:@[@"a",@"z"]];
    NSLog(@"contains nil: %@", dict);
    XCTAssertNotNil(dict);
    NSNull *obj = [NSNull null];
    if (obj == nil) {
        NSLog(@"nil");
    }
    if (obj) {
        
    }
    else {
        NSLog(@"empty");
    }
    if ([obj isEqual:[NSNull null]]) {
        NSLog(@"NULL");
    }
}

- (void)testDelete
{
    id rtn;
    rtn = [redis addValue:@"1" forKey:@"myset"];
    XCTAssertTrue([rtn isEqualToNumber:@YES]);
    rtn = [redis removeObject:@"0" forKey:@"myset"];
    XCTAssertTrue([rtn isEqualToNumber:@NO]);
    rtn = [redis removeObject:@"1" forKey:@"myset"];
    XCTAssertTrue([rtn isEqualToNumber:@YES]);
    
    rtn = [redis setDictionary:@{@"1":@"val"} forKey:@"myhash"];
    XCTAssertTrue([rtn isEqualToString:@"OK"]);
    rtn = [redis removeObjectForDictionaryKey:@"2" forKey:@"myhash"];
    XCTAssertTrue([rtn isEqualToNumber:@0]);
    rtn = [redis removeObjectForDictionaryKey:@"1" forKey:@"myhash"];
    XCTAssertTrue([rtn isEqualToNumber:@1]);
    
    
}

- (void)testMoveMember
{
    NSString *key1= @"myset1";
    NSString *key2= @"myset2";
    redis.databaseNumber = @9;
    
    // prepare values
    id rtn;
    rtn = [redis addValues:@[@"1",@"3",@"5"] forKey:key1];
    XCTAssertTrue([rtn isEqualToNumber:@3]);
    
    rtn = [redis addValues:@[@"2",@"3",@"4"] forKey:key2];
    XCTAssertTrue([rtn isEqualToNumber:@3]);
    
    // test
    XCTAssertTrue( [redis moveMember:@"1" fromKey:key1 toKey:key2]);
    XCTAssertFalse( [redis moveMember:@"1" fromKey:key1 toKey:key2],
                   @"値がないと失敗");
    XCTAssertTrue( [redis moveMember:@"3" fromKey:key1 toKey:key2],
                   @"重複してても大丈夫");
    XCTAssertTrue( [redis moveMember:@"5" fromKey:key1 toKey:@"no-key"],
                   @"Destinationがなくても大丈夫");
    
    
    [redis deleteObjectForKey:key1];
    [redis deleteObjectForKey:key2];
}
@end
