//
//  RedisTests.m
//  RedisTests
//
//  Created by Shintaro Abe on 1/5/14.
//  Copyright (c) 2014 dictav. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DSRedis.h"

@interface ARedisTests : XCTestCase

@end

@implementation ARedisTests
{
    DSRedis *redis;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    redis = [[DSRedis alloc] initWithServer:@"localhost" port:11235 password:nil];
    [DSRedis setSharedRedis:redis];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPing
{
    XCTAssertTrue([redis ping]);
}

@end
