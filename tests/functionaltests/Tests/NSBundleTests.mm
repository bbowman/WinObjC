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

#import <TestFramework.h>
#import <Foundation/Foundation.h>
#import <UWP/WindowsFoundation.h>
#import <UWP/WindowsStorage.h>

class NSBundleTests {
public:
    BEGIN_TEST_CLASS(NSBundleTests)
    END_TEST_CLASS()

    TEST_CLASS_SETUP(NSURLClassSetup) {
        return FunctionalTestSetupUIApplication();
    }

    TEST_CLASS_CLEANUP(NSBundleCleanup) {
        return FunctionalTestCleanupUIApplication();
    }

    TEST_METHOD(MSAppxURL) {
        LOG_INFO("MSAppxURL test: ");

        NSURL* resourceURL = [[NSBundle mainBundle] URLForResource:@"FunctionalTests" withExtension:@"dll"];
        NSURL* msAppxURL = [[NSBundle mainBundle] _msAppxURLForResourceWithURL:resourceURL];
        ASSERT_OBJCEQ([NSURL URLWithString:[@"ms-appx:///" stringByAppendingString:[resourceURL lastPathComponent]]], msAppxURL);

        WFUri* msAppxURI = [WFUri makeUri:msAppxURL.absoluteString];

        // Verify that the file can be accessed
        __block BOOL success = NO;
        __block BOOL signaled = NO;
        __block NSCondition* condition = [[NSCondition new] autorelease];

        [WSStorageFile getFileFromApplicationUriAsync:msAppxURI
            success:^void(WSStorageFile* file) {
                [condition lock];
                success = YES;
                signaled = YES;
                [condition signal];
                [condition unlock];
            }
            failure:^void(NSError* error) {
                LOG_ERROR([[error description] UTF8String]);
                [condition lock];
                signaled = YES;
                [condition signal];
                [condition unlock];
            }];

        [condition lock];
        ASSERT_TRUE(signaled || [condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]]);
        [condition unlock];

        ASSERT_EQ(YES, success);
    }
};