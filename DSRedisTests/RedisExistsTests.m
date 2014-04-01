//
//  RedisExistsTests.m
//  KawaiiShop
//
//  Created by Shintaro Abe on 2013/12/03.
//  Copyright (c) 2013年 Abe Shintaro. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSRedis.h"

@interface RedisExistsTests : XCTestCase

@end

@implementation RedisExistsTests
{
    DSRedis *redis;
}

static DSRedis *remoteRedis;
- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    redis = [DSRedis sharedRedis];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
    for (NSString *key in [redis allKeys:@"*"]) {
        [redis deleteObjectForKey:key];
    }
}

- (void)testExistsObject
{
    NSString *key = @"hoge";
    NSString *obj = @"mochi";
    XCTAssertFalse([redis hasKey:key]);
    
    [redis setValue:obj forKey:key];
    XCTAssertTrue([redis hasKey:key]);
}

- (void)testHasMember
{
    NSString *key = @"hoge";
    NSString *obj = @"mochi";
    XCTAssertFalse([redis hasMember:obj forKey:key]);
    
    [redis addValue:obj forKey:key];
    XCTAssertTrue([redis hasMember:obj forKey:key]);
}

- (void)testHasDictionaryKey
{
    NSString *key = @"hoge";
    NSString *dictKey = @"piyo";
    NSString *obj = @"mochi";
    XCTAssertFalse([redis hasDictionaryKey:dictKey forKey:key]);
    
    NSDictionary *dict = @{dictKey: obj};
    [redis setDictionary:dict forKey:key];
    XCTAssertTrue([redis hasDictionaryKey:dictKey forKey:key]);
}
@end
