//
//  IAFacebookEngine.h
//
//  Created by Ivan Ablamskyi on 1/27/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "IAOAuth.h"

typedef void (^IAFacebookEngineCompletionBlock)(NSError *error, id json);

@protocol IAFacebookEngineDelegate;

@interface IAFacebookEngine : IAOAuth {
@private
	id <IAFacebookEngineDelegate> _delegate;
	NSString* _accessToken;
	NSDate* _expirationDate;
	NSArray *_perms;
	IAFacebookEngineCompletionBlock _oAuthCompletionBlock;
}

@property (assign) id <IAFacebookEngineDelegate> delegate;
@property (nonatomic, copy) NSString* accessToken;
@property (nonatomic, copy) NSDate* expirationDate;
@property (nonatomic, retain) NSArray *perms;


- (id)initWithDelegate:(id <IAFacebookEngineDelegate>)delegate;
- (void)authenticateWithCompletionBlock:(IAFacebookEngineCompletionBlock)completionBlock;
- (void)resumeAuthenticationFlowWithURL:(NSURL *)url;
- (void)cancelAuthentication;
- (void)forgetStoredToken;

- (void)postGraphTo:(NSString *)path withParams:(NSDictionary *)params withCompletionBlock:(IAFacebookEngineCompletionBlock)completionBlock;
- (void)requestGraphTo:(NSString *)path withParams:(NSDictionary *)params andMehtod:(NSString *)method andCompletionBlock:(IAFacebookEngineCompletionBlock)completionBlock;

@end

@protocol IAFacebookEngineDelegate <NSObject>

- (void)facebookEngine:(IAFacebookEngine *)engine needsToOpenURL:(NSURL *)url;
- (void)facebookEngine:(IAFacebookEngine *)engine statusUpdate:(NSString *)message;

@end