//
//  IATwitterEngine.h
//
//  Created by Ivan Ablamskyi on 1/23/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "IAOAuth.h"

@protocol IATwitterEngineDelegate;

typedef void (^IATwitterEngineCompletionBlock)(NSError *error, id json);

@interface IATwitterEngine : IAOAuth {
	IATwitterEngineCompletionBlock _oAuthCompletionBlock;
    NSString *_screenName;
	id <IATwitterEngineDelegate> _delegate;
}

@property (assign) id <IATwitterEngineDelegate> delegate;
@property (nonatomic, copy, readonly) NSString *screenName;

- (id)initWithDelegate:(id <IATwitterEngineDelegate>)delegate;
- (void)authenticateWithCompletionBlock:(IATwitterEngineCompletionBlock)completionBlock;
- (void)resumeAuthenticationFlowWithURL:(NSURL *)url;
- (void)cancelAuthentication;
- (void)forgetStoredToken;
- (void)sendTweet:(NSDictionary *)tweetParams withCompletionBlock:(IATwitterEngineCompletionBlock)completionBlock;

@end


@protocol IATwitterEngineDelegate <NSObject>

- (void)twitterEngine:(IATwitterEngine *)engine needsToOpenURL:(NSURL *)url;
- (void)twitterEngine:(IATwitterEngine *)engine statusUpdate:(NSString *)message;

@end