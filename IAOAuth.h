//
//  IAOAuth.h
//
//  Created by Ivan Ablamskyi on 1/23/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "AFHTTPClient.h"

#ifndef IB_IS_RUNNING_ON_LION
#define IB_IS_RUNNING_ON_LION (nil != NSClassFromString(@"NSPopover"))
#endif

typedef enum _IAOAuthTokenType {
    IAOAuthRequestToken,
    IAOAuthAccessToken,
}
IAOAuthTokenType;

typedef enum _IAOAuthSignatureMethod {
    IAOAuthPlainText,
    IAOAuthHMAC_SHA1,
} IAOAuthSignatureMethod;

@interface IAOAuth : AFHTTPClient {
@private
    IAOAuthTokenType _tokenType;
    IAOAuthSignatureMethod _signatureMethod;
    NSString *_consumerSecret;
    NSString *_tokenSecret;
    NSString *_callbackURL;
    NSString *_verifier;
    NSMutableDictionary *_oAuthValues;
    NSMutableDictionary *_customValues;
	
	NSString *_token;
	NSString *_consumerKey;
}

@property (nonatomic, readonly) IAOAuthTokenType tokenType;
@property (nonatomic, readonly) IAOAuthSignatureMethod signatureMethod;

@property (nonatomic, readonly, copy) NSString *consumerKey;
@property (nonatomic, readonly, copy) NSString *consumerSecret;
@property (nonatomic, readonly, copy) NSString *callbackURL;
@property (nonatomic, readonly, copy) NSString *token;
@property (nonatomic, readonly, copy) NSString *tokenSecret;
@property (nonatomic, readonly, copy) NSString *verifier;
@property (nonatomic, retain, readonly) NSMutableDictionary *customValues;

- (id)initWithHostName:(NSString *)hostName 
    customHeaderFields:(NSDictionary *)headers
       signatureMethod:(IAOAuthSignatureMethod)signatureMethod
           consumerKey:(NSString *)consumerKey
        consumerSecret:(NSString *)consumerSecret
           callbackURL:(NSString *)callbackURL;

- (id)initWithHostName:(NSString *)hostName
    customHeaderFields:(NSDictionary *)headers
       signatureMethod:(IAOAuthSignatureMethod)signatureMethod
           consumerKey:(NSString *)consumerKey
        consumerSecret:(NSString *)consumerSecret;

- (BOOL)isAuthenticated;
- (void)resetOAuthToken;
- (void)setAccessToken:(NSString *)token secret:(NSString *)tokenSecret;
- (void)fillTokenWithResponseBody:(NSString *)body type:(IAOAuthTokenType)tokenType;

- (void)addToKeychainUsingName:(NSString *)inName andValue:(NSString *)inValue;
- (void)removeValueFromKeychainUsingName:(NSString *)inName;
- (NSString *)findValueFromKeychainUsingName:(NSString *)inName;

@end
