//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include <TestFramework.h>
#include <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, NSURLConnectionDelegateType) {
    NSURLConnectionDelegateDidReceiveResponse,
    NSURLConnectionDelegateDidReceiveData,
    NSURLConnectionDelegateDidFailWithError
};

@interface NSURLConnectionTestHelper : NSObject <NSURLConnectionDelegate>
@property NSCondition* condition;
@property dispatch_queue_t queue;
@property NSMutableArray* delegateCallOrder;
@property (copy) NSURLResponse* response;
@property (copy) NSData* data;
@property (copy) NSError* error;

- (instancetype)init;
- (NSURLConnection*)createConnectionWithRequest:(NSString*)URLString;

@end

@implementation NSURLConnectionTestHelper

- (instancetype)init {
    if (self = [super init]) {
        self->_condition = [[NSCondition alloc] init];
        self->_queue = dispatch_queue_create("NSURLConnectionDelegateCallOrder", NULL);
        self->_delegateCallOrder = [NSMutableArray array];
    }
    return self;
}

- (NSURLConnection*)createConnectionWithRequest:(NSString*)URLString {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    return connection;
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    dispatch_sync(self.queue, ^{
        [self.delegateCallOrder addObject:[NSNumber numberWithInteger:NSURLConnectionDelegateDidReceiveResponse]];
    });
    [self.condition lock];
    self.response = response;
    [self.condition signal];
    [self.condition unlock];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(nonnull NSData*)data {
    dispatch_sync(self.queue, ^{
        [self.delegateCallOrder addObject:[NSNumber numberWithInteger:NSURLConnectionDelegateDidReceiveData]];
    });

    [self.condition lock];
    self.data = data;
    [self.condition signal];
    [self.condition unlock];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)e {
    dispatch_sync(self.queue, ^{
        [self.delegateCallOrder addObject:[NSNumber numberWithInteger:NSURLConnectionDelegateDidFailWithError]];
    });

    [self.condition lock];
    self.error = e;
    [self.condition signal];
    [self.condition unlock];
}

@end

class NSURLConnectionTests {
public:
    BEGIN_TEST_CLASS(NSURLConnectionTests)
    TEST_CLASS_PROPERTY(L"UAP:AppXManifest", L"NSURL.AppxManifest.xml")
    END_TEST_CLASS()

    TEST_CLASS_SETUP(NSURLClassSetup) {
        return FunctionalTestSetupUIApplication();
    }

    TEST_CLASS_CLEANUP(NSURLClassCleanup) {
        return FunctionalTestCleanupUIApplication();
    }

    /**
     * Test to verify a request can be successfully made and a valid response and data is received.
     */
    TEST_METHOD(RequestWithURL) {
        NSURLConnectionTestHelper* connectionTestHelper = [[NSURLConnectionTestHelper alloc] init];
        NSString* urlString = @"https://httpbin.org/cookies/set?winobjc=awesome";
        LOG_INFO("Establishing download task with url %@", urlString);
        NSURLConnection* connection = [connectionTestHelper createConnectionWithRequest:urlString];
        [connection start];

        // Wait for data.
        [connectionTestHelper.condition lock];
        for (int i = 0; (i < 5) && ([connectionTestHelper.delegateCallOrder count] != 2); i++) {
            [connectionTestHelper.condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:c_testTimeoutInSec]];
        }
        ASSERT_EQ_MSG(2, [connectionTestHelper.delegateCallOrder count], "FAILED: We should have received two delegates call by now!");
        [connectionTestHelper.condition unlock];

        // Make sure we received a response.
        ASSERT_EQ_MSG(NSURLConnectionDelegateDidReceiveResponse,
                      [(NSNumber*)[connectionTestHelper.delegateCallOrder objectAtIndex:0] integerValue],
                      "FAILED: didReceiveResponse should be the first delegate to be called!");
        ASSERT_TRUE_MSG((connectionTestHelper.response != nil), "FAILED: Response cannot be empty!");
        NSURLResponse* response = connectionTestHelper.response;
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            ASSERT_FALSE_MSG(true, "FAILED: Response should be of kind NSHTTPURLResponse class!");
        }
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        LOG_INFO("Received HTTP response status: %ld", [httpResponse statusCode]);
        ASSERT_EQ_MSG(200, [httpResponse statusCode], "FAILED: HTTP status 200 expected!");
        LOG_INFO("Received HTTP response headers: %d", [httpResponse allHeaderFields]);

        // Make sure we received data.
        ASSERT_EQ_MSG(NSURLConnectionDelegateDidReceiveData,
                      [(NSNumber*)[connectionTestHelper.delegateCallOrder objectAtIndex:1] integerValue],
                      "FAILED: didReceiveData should be the first delegate to be called!");
        ASSERT_TRUE_MSG((connectionTestHelper.data != nil), "FAILED: We should have received some data!");
        LOG_INFO("Received data: %@", [[NSString alloc] initWithData:connectionTestHelper.data encoding:NSUTF8StringEncoding]);

        // Make sure there was no error.
        ASSERT_TRUE_MSG((connectionTestHelper.error == nil), "FAILED: Connection returned error %@!", connectionTestHelper.error);
    }

    /**
     * Test to verify a request can be successfully made but no data was received and a valid response error code was received.
     */
    TEST_METHOD(RequestWithURL_Failure) {
        NSURLConnectionTestHelper* connectionTestHelper = [[NSURLConnectionTestHelper alloc] init];
        NSString* urlString = @"https://httpbin.org/status/404";
        LOG_INFO("Establishing download task with url %@", urlString);
        NSURLConnection* connection = [connectionTestHelper createConnectionWithRequest:urlString];
        [connection start];

        // Wait for a response.
        [connectionTestHelper.condition lock];

        for (int i = 0; (i < 5) && ([connectionTestHelper.delegateCallOrder count] != 1); i++) {
            [connectionTestHelper.condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:c_testTimeoutInSec]];
        }
        ASSERT_EQ_MSG(1, [connectionTestHelper.delegateCallOrder count], "FAILED: We should have received one delegate call by now!");
        [connectionTestHelper.condition unlock];

        // Make sure we received a response.
        ASSERT_EQ_MSG(NSURLConnectionDelegateDidReceiveResponse,
                      [(NSNumber*)[connectionTestHelper.delegateCallOrder objectAtIndex:0] integerValue],
                      "FAILED: didReceiveResponse should be the first delegate to be called!");
        ASSERT_TRUE_MSG((connectionTestHelper.response != nil), "FAILED: Response cannot be empty!");
        NSURLResponse* response = connectionTestHelper.response;
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            ASSERT_FALSE_MSG(true, "FAILED: Response should be of kind NSHTTPURLResponse class!");
        }
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        LOG_INFO("Received HTTP response status: %ld", [httpResponse statusCode]);
        ASSERT_EQ_MSG(404, [httpResponse statusCode], "FAILED: HTTP status 404 was expected!");

        // Make sure we did not receive any data.
        ASSERT_TRUE_MSG((connectionTestHelper.data == nil), "FAILED: We should not have received any data!");

        // Make sure there was no error.
        ASSERT_TRUE_MSG((connectionTestHelper.error == nil), "FAILED: Connection returned error %@!", connectionTestHelper.error);
    }
};