//
//  IATwitterEngine.m
//
//  Created by Ivan Ablamskyi on 1/23/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "IATwitterEngine.h"

#define TW_HOSTNAME @"https://api.twitter.com"
#define TW_REQUEST_TOKEN @"oauth/request_token"
#define TW_ACCESS_TOKEN @"oauth/access_token"
#define TW_STATUS_UPDATE @"1/statuses/update.json"

// Never share this information
#if !defined(TW_CONSUMER_KEY) || !defined(TW_CONSUMER_SECRET)
#error  Define your Consumer Key and Secret 
#endif

// This will be called after the user authorizes your app
#ifndef TW_CALLBACK_URL
#define TW_CALLBACK_URL @"iatwitterengine://auth_token"
#endif

#define TW_AUTHORIZE(__TOKEN__) [NSString stringWithFormat:@"https://api.twitter.com/oauth/authorize?oauth_token=%@", __TOKEN__]

@interface IATwitterEngine  ( /* Private */ ) 
@property (nonatomic, copy, readwrite) NSString *screenName;
@property (copy) IATwitterEngineCompletionBlock oAuthCompletionBlock;

- (void)removeOAuthTokenFromKeychain;
- (void)storeOAuthTokenInKeychain;
- (void)retrieveOAuthTokenFromKeychain;

@end

@implementation IATwitterEngine
@synthesize delegate = _delegate;
@synthesize screenName = _screenName;
@synthesize oAuthCompletionBlock = _oAuthCompletionBlock;

- (id)initWithDelegate:(id <IATwitterEngineDelegate>)delegate {
    self = [super initWithHostName:TW_HOSTNAME customHeaderFields:nil signatureMethod:IAOAuthHMAC_SHA1 consumerKey:TW_CONSUMER_KEY consumerSecret:TW_CONSUMER_SECRET callbackURL:TW_CALLBACK_URL];
    
    if (self) {
        self.oAuthCompletionBlock = nil;
        self.screenName = nil;
        self.delegate = delegate;
        
        // Retrieve OAuth access token (if previously stored)
        [self retrieveOAuthTokenFromKeychain];
    }
    
    return self;
}

- (void)dealloc {
	self.oAuthCompletionBlock = nil;
	self.screenName = nil;
	self.delegate = nil;
	[super dealloc];
}

#pragma mark - OAuth Access Token store/retrieve
- (void)removeOAuthTokenFromKeychain {
	[self removeValueFromKeychainUsingName:@"oauth_token"];
	[self removeValueFromKeychainUsingName:@"oauth_token_secret"];
}

- (void)storeOAuthTokenInKeychain {
	[self addToKeychainUsingName:@"oauth_token" andValue:self.token];
	[self addToKeychainUsingName:@"oauth_token_secret" andValue:self.tokenSecret];
}

- (void)retrieveOAuthTokenFromKeychain {
	NSString	*token = [self findValueFromKeychainUsingName:@"oauth_token"], 
				*tokenSecret = [self findValueFromKeychainUsingName:@"oauth_token_secret"];
	
	if (token && tokenSecret) {
		[self setAccessToken:token secret:tokenSecret];
	}
}

#pragma mark - OAuth Authentication Flow
- (void)authenticateWithCompletionBlock:(IATwitterEngineCompletionBlock)completionBlock {
    // Store the Completion Block to call after Authenticated
    self.oAuthCompletionBlock = completionBlock;
    
    // First we reset the OAuth token, so we won't send previous tokens in the request
    [self resetOAuthToken];
    
    // OAuth Step 1 - Obtain a request token
	[self postPath:TW_REQUEST_TOKEN parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		// Fill the request token with the returned data
		[self fillTokenWithResponseBody:[operation responseString] type:IAOAuthRequestToken];
		
		// OAuth Step 2 - Redirect user to authorization page
		NSAssert(self.delegate && [self.delegate respondsToSelector:@selector(twitterEngine:statusUpdate:)], @"Delegate %@ should implement statusUpdate:", self.delegate);
		[self.delegate twitterEngine:self statusUpdate:@"Waiting for user authorization..."];
		
		NSAssert(self.delegate && [self.delegate respondsToSelector:@selector(twitterEngine:needsToOpenURL:)], @"Delegate %@ should implement needsToOpenURL:", self.delegate);
		NSURL *url = [NSURL URLWithString:TW_AUTHORIZE(self.token)];
		[self.delegate twitterEngine:self needsToOpenURL:url];

	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		completionBlock(error, nil);
		self.oAuthCompletionBlock = nil;

	}];

	NSAssert(self.delegate && [self.delegate respondsToSelector:@selector(twitterEngine:statusUpdate:)], @"Delegate %@ should implement statusUpdate:", self.delegate);
	[self.delegate twitterEngine:self statusUpdate:@"Requesting Tokens..."];
}

- (void)resumeAuthenticationFlowWithURL:(NSURL *)url {
    // Fill the request token with data returned in the callback URL
    [self fillTokenWithResponseBody:url.query type:IAOAuthRequestToken];
    
    // OAuth Step 3 - Exchange the request token with an access token
	[self postPath:TW_ACCESS_TOKEN
		parameters:nil
		   success:^(AFHTTPRequestOperation *operation, id responseObject) {
			   [self fillTokenWithResponseBody:[operation responseString] type:IAOAuthAccessToken];
			   
			   // Retrieve the user's screen name
			   self.screenName = [self.customValues valueForKey:@"screen_name"];
			   
			   // Store the OAuth access token
			   [self storeOAuthTokenInKeychain];
			   
			   // Finished, return to previous method
			   if (self.oAuthCompletionBlock) self.oAuthCompletionBlock(nil, nil);
			   self.oAuthCompletionBlock = nil;
		   } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
			   if (self.oAuthCompletionBlock) self.oAuthCompletionBlock(error, nil);
			   self.oAuthCompletionBlock = nil;
		   }
	 ];
	
    [self.delegate twitterEngine:self statusUpdate:@"Authenticating..."];
}

- (void)cancelAuthentication {
    NSDictionary *ui = [NSDictionary dictionaryWithObjectsAndKeys:@"Authentication cancelled.", NSLocalizedDescriptionKey, nil];
    NSError *error = [NSError errorWithDomain:[[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".ErrorDomain"] code:401 userInfo:ui];
    
    if (self.oAuthCompletionBlock) self.oAuthCompletionBlock(error, nil);
    self.oAuthCompletionBlock = nil;
}

- (void)forgetStoredToken {
    [self removeOAuthTokenFromKeychain];
    
    [self resetOAuthToken];
    self.screenName = nil;
}

#pragma mark - Public Methods
- (void)sendTweet:(NSDictionary *)tweetParams withCompletionBlock:(IATwitterEngineCompletionBlock)completionBlock {
    if (!self.isAuthenticated) {
        [self authenticateWithCompletionBlock:^(NSError *error, id json) {
            if (error) {
                // Authentication failed, return the error
                completionBlock(error, json);
            } else {
                // Authentication succeeded, call this method again
                [self sendTweet:tweetParams withCompletionBlock:completionBlock];
            }
        }];
        
        // This method will be called again once the authentication completes
        return;
    }
    
    // Fill the post body with the tweet
	
	[[AFJSONRequestOperation JSONRequestOperationWithRequest:[self requestWithMethod:@"POST" path:TW_STATUS_UPDATE parameters:tweetParams] 
													success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
														completionBlock(nil, JSON);
													} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
														if (response.statusCode == 401 || response.statusCode == 403) {
															// Auth was revoken - foreget
															[self forgetStoredToken];
															NSLog(@"frs:twauth revoken external");
															[self sendTweet:tweetParams withCompletionBlock:completionBlock];
															
															return;
														}
														completionBlock(error, JSON);
													}
	 ] start];

    [self.delegate twitterEngine:self statusUpdate:@"Sending tweet..."];
}

@end
