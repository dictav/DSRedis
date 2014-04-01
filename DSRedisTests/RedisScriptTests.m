//
//  RedisScriptTests.m
//  KawaiiShop
//
//  Created by Shintaro Abe on 2013/12/12.
//  Copyright (c) 2013年 Abe Shintaro. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSRedis.h"

@interface RedisScriptTests : XCTestCase

@end

@implementation RedisScriptTests

static DSRedis *remoteRedis;
- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testExample
{
    DSRedis *redis = [DSRedis sharedRedis];
    NSString *script = @"return 1";
    NSString *sha1 = [redis uploadScript:script];
    XCTAssertTrue([sha1 isEqualToString: @"e0e1f9fabfc9d4800c877a703b823ac0578ff8db"]);
    NSNumber *ret = [redis evalWithSHA:sha1 keys:@[] args:@[]];
    XCTAssertTrue([ret isEqualToNumber: @(1)]);
}

@end
