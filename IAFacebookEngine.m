//
//  IAFacebookEngine.m
//
//  Created by Ivan Ablamskyi on 1/27/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "IAFacebookEngine.h"
#import "NSString+UUID.h"

#define FB_HOSTNAME @"https://graph.facebook.com"
#define FB_REQUEST_TOKEN @"oauth/authorize"
#define FB_ACCESS_TOKEN @"oauth/access_token"


#define kFBAuthorizeWithScopeURL @"https://graph.facebook.com/oauth/authorize?client_id=%@&redirect_uri=%@&scope=%@&type=user_agent&display=touch"


// Never share this information
#if !defined(FB_APP_KEY) || !defined(FB_APP_SECRET)
#error  Define your Application ID and App Secret
#endif

// This will be called after the user authorizes your app
#ifndef FB_CALLBACK_URL
#define FB_CALLBACK_URL @"https://www.facebook.com/connect/login_success.html"
#endif

@interface IAFacebookEngine  ( /* Private */ ) 
@property (copy) IAFacebookEngineCompletionBlock oAuthCompletionBlock;

- (void)removeOAuthTokenFromKeychain;
- (void)storeOAuthTokenInKeychain;
- (void)retrieveOAuthTokenFromKeychain;
- (BOOL)isSessionValid;

@end

@implementation IAFacebookEngine
@synthesize delegate = _delegate;
@synthesize oAuthCompletionBlock = _oAuthCompletionBlock;
@synthesize accessToken = _accessToken,
			expirationDate = _expirationDate;
@synthesize perms = _perms;

- (id)initWithDelegate:(id <IAFacebookEngineDelegate>)delegate {
    self = [super initWithHostName:FB_HOSTNAME customHeaderFields:nil signatureMethod:IAOAuthHMAC_SHA1 consumerKey:FB_APP_KEY consumerSecret:FB_APP_SECRET callbackURL:FB_CALLBACK_URL];
    
    if (self) {
        self.oAuthCompletionBlock = nil;
        self.delegate = delegate;
        
        // Retrieve OAuth access token (if previously stored)
        [self retrieveOAuthTokenFromKeychain];
    }
    
    return self;
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];

	[params setValue:@"json" forKey:@"format"];
//	[params setValue:@"ios" forKey:@"sdk"];
//	[params setValue:@"2" forKey:@"sdk_version"];
	if (self.accessToken && [self.accessToken length] > 0) {
		[params setValue:self.accessToken forKey:@"access_token"];
	}
	
	
	return [super requestWithMethod:method path:path parameters:params];
}
#pragma mark - OAuth Access Token store/retrieve
- (void)removeOAuthTokenFromKeychain {
	[self removeValueFromKeychainUsingName:@"FBAccessTokenKey"];
	[self removeValueFromKeychainUsingName:@"FBExpirationDateKey"];
	self.accessToken = nil;
	self.expirationDate = nil;
}

- (void)storeOAuthTokenInKeychain {
	[self addToKeychainUsingName:@"FBAccessTokenKey" andValue:self.accessToken];
	[self addToKeychainUsingName:@"FBExpirationDateKey" andValue:[self.expirationDate description]];
}

- (void)retrieveOAuthTokenFromKeychain {
	NSString	*token = [self findValueFromKeychainUsingName:@"FBAccessTokenKey"], 
				*expirationDate = [self findValueFromKeychainUsingName:@"FBExpirationDateKey"];
	
	if (token && expirationDate) {
		self.accessToken = token;
		self.expirationDate = [NSDate dateWithString:expirationDate];
	}
}

#pragma mark - OAuth Authentication Flow
/**
 * @return boolean - whether this object has an non-expired session token
 */
- (BOOL)isSessionValid { return (self.accessToken != nil && self.expirationDate != nil && NSOrderedDescending == [self.expirationDate compare:[NSDate date]]); }


- (void)authenticateWithCompletionBlock:(IAFacebookEngineCompletionBlock)completionBlock {
    // Store the Completion Block to call after Authenticated
    self.oAuthCompletionBlock = completionBlock;
	
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								   FB_APP_KEY, @"client_id",
								   FB_CALLBACK_URL, @"redirect_uri",
								   @"user_agent", @"type",
								   @"touch", @"display",
//								   @"popup", @"display",
								   @"token", @"response_type",
								   nil];
	if (self.perms && [self.perms count] > 0) {
		[params setObject:[self.perms componentsJoinedByString:@","] forKey:@"scope"];
	}
	
	[self getPath:FB_REQUEST_TOKEN parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if ([operation.response.URL.path hasSuffix:@"login.php"]) {
			// OAuth Step 2 - Redirect user to authorization page
			NSAssert(self.delegate && [self.delegate respondsToSelector:@selector(twitterEngine:statusUpdate:)], @"Delegate %@ should implement statusUpdate:", self.delegate);
			[self.delegate facebookEngine:self statusUpdate:@"Waiting for user authorization..."];
			
			NSAssert(self.delegate && [self.delegate respondsToSelector:@selector(twitterEngine:needsToOpenURL:)], @"Delegate %@ should implement needsToOpenURL:", self.delegate);
			[self.delegate facebookEngine:self needsToOpenURL:operation.request.URL];
		}
		
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		completionBlock(error, nil);
		self.oAuthCompletionBlock = nil;
		
	}];
	
	NSAssert(self.delegate && [self.delegate respondsToSelector:@selector(twitterEngine:statusUpdate:)], @"Delegate %@ should implement statusUpdate:", self.delegate);
	[self.delegate facebookEngine:self statusUpdate:@"Requesting access..."];
}

- (void)resumeAuthenticationFlowWithURL:(NSURL *)url {
	NSString *query = [url fragment];
	
	if (!query) {
		query = [url query];
	}
	
	NSArray *pairs = [query componentsSeparatedByString:@"&"];
	
	NSString *token = nil, 
			 *date = nil, 
			 *errorInfo = nil;
	
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [elements objectAtIndex:0];
        NSString *value = [[elements objectAtIndex:1] urlDecodedString];
		
        if ([key isEqualToString:@"access_token"]) {
			token = value;
        } 
		else if ([key isEqualToString:@"expires_in"]) {
            date = value;
        } 
		else if ([key isEqualToString:@"error_description"]) {
			errorInfo = value;
		}
		else {
            [self.customValues setValue:value forKey:key];
        }
	}
	
	if (token && date && !errorInfo) {
		self.accessToken = token;
		self.expirationDate = [NSDate dateWithTimeIntervalSinceNow:[date floatValue]];
		
		[self storeOAuthTokenInKeychain];
		
		// Finished, return to previous method
		if (self.oAuthCompletionBlock) self.oAuthCompletionBlock(nil, nil);
		self.oAuthCompletionBlock = nil;
	}
	else {
		if (self.oAuthCompletionBlock) {
			NSDictionary *ui = [NSDictionary dictionaryWithObjectsAndKeys:errorInfo ? errorInfo : @"Permittions denied.", NSLocalizedDescriptionKey, nil];
			NSError *error = [NSError errorWithDomain:[[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".FBErrorDomain"] code:401 userInfo:ui];
			self.oAuthCompletionBlock(error, nil);
		}
		self.oAuthCompletionBlock = nil;
	}
}

- (void)cancelAuthentication {
    NSDictionary *ui = [NSDictionary dictionaryWithObjectsAndKeys:@"Authentication cancelled.", NSLocalizedDescriptionKey, nil];
    NSError *error = [NSError errorWithDomain:[[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".FBErrorDomain"] code:401 userInfo:ui];
    
    if (self.oAuthCompletionBlock) self.oAuthCompletionBlock(error, nil);
    self.oAuthCompletionBlock = nil;
}

- (void)forgetStoredToken {
    [self removeOAuthTokenFromKeychain];
    [self resetOAuthToken];
}

#pragma mark - Public methods
- (void)postGraphTo:(NSString *)path withParams:(NSDictionary *)params withCompletionBlock:(IAFacebookEngineCompletionBlock)completionBlock {
	[self requestGraphTo:path withParams:params andMehtod:@"POST" andCompletionBlock:completionBlock];
}

- (void)requestGraphTo:(NSString *)path withParams:(NSDictionary *)params andMehtod:(NSString *)method andCompletionBlock:(IAFacebookEngineCompletionBlock)completionBlock {
	if (![self isSessionValid]) {
		// Need authorize then recall post method
		[self authenticateWithCompletionBlock:^(NSError *error, id json) {
			if (error) {
                // Authentication failed, return the error
				[self forgetStoredToken];
                completionBlock(error, json);
            } else {
				[self requestGraphTo:path withParams:params andMehtod:method andCompletionBlock:completionBlock];
			}
		}];
		return;
	}
	
	NSMutableURLRequest *request = [self requestWithMethod:method path:path parameters:params];
	[[AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
		completionBlock(nil, JSON);
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
		if ( response.statusCode == 401 ||
			( [[[JSON valueForKey:@"error"] valueForKey:@"type"] isEqualToString:@"OAuthException"] &&
			  [[[JSON valueForKey:@"message"] valueForKey:@"type"] rangeOfString:@"not authorized application"].length > 0)
			){
			
			// Removed auth - try reauthorize
			[self forgetStoredToken];
			[self requestGraphTo:path withParams:params andMehtod:method andCompletionBlock:completionBlock];
			return;
		}
		completionBlock(error, JSON);
	}] start];
}


@end
