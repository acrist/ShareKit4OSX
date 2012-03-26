//
//  IAOAuth.m
//
//  Created by Ivan Ablamskyi on 1/23/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "IAOAuth.h"
#include <sys/time.h>
#import <CommonCrypto/CommonHMAC.h>
#import "NSData+Base64.h"
#import "NSString+UUID.h"

static const NSString *oauthVersion = @"1.0";

static const NSString *oauthSignatureMethodName[] = {
    @"PLAINTEXT",
    @"HMAC-SHA1",
};

static inline NSDictionary * AFParametersFromQueryString(NSString *queryString) {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (queryString) {
        NSScanner *parameterScanner = [[[NSScanner alloc] initWithString:queryString] autorelease];
        NSString *name = nil;
        NSString *value = nil;
        
        while (![parameterScanner isAtEnd]) {
            name = nil;        
            [parameterScanner scanUpToString:@"=" intoString:&name];
            [parameterScanner scanString:@"=" intoString:NULL];
            
            value = nil;
            [parameterScanner scanUpToString:@"&" intoString:&value];
            [parameterScanner scanString:@"&" intoString:NULL];		
            
            if (name && value) {
                [parameters setValue:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:[name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
    
    return parameters;
}


@interface IAOAuth ( /* Private Methods */ )

@property (nonatomic, assign) IAOAuthTokenType tokenType;
@property (nonatomic, assign) IAOAuthSignatureMethod signatureMethod;
@property (nonatomic, readwrite, copy) NSString *consumerKey;
@property (nonatomic, readwrite, copy) NSString *consumerSecret;
@property (nonatomic, readwrite, copy) NSString *callbackURL;
@property (nonatomic, readwrite, copy) NSString *token;
@property (nonatomic, readwrite, copy) NSString *tokenSecret;
@property (nonatomic, readwrite, copy) NSString *verifier;

// Some other properties
@property (nonatomic, retain, readwrite) NSMutableDictionary *oAuthValues, *customValues;

- (NSString *)generatePlaintextSignatureFor:(NSString *)baseString;
- (NSString *)generateHMAC_SHA1SignatureFor:(NSString *)baseString;
- (NSString *)findValueFromKeychainUsingName:(NSString *)inName returningItem:(SecKeychainItemRef *)outKeychainItemRef;

@end

@implementation IAOAuth
@synthesize signatureMethod = _signatureMethod;
@synthesize verifier = _verifier;
@synthesize token = _token;
@synthesize tokenType = _tokenType;
@synthesize tokenSecret = _tokenSecret;
@synthesize consumerKey = _consumerKey;
@synthesize consumerSecret = _consumerSecret;
@synthesize callbackURL = _callbackURL;

@synthesize oAuthValues = _oAuthValues, customValues = _customValues;


#pragma mark - Initialization

- (id)initWithHostName:(NSString *)hostName
    customHeaderFields:(NSDictionary *)headers
       signatureMethod:(IAOAuthSignatureMethod)signatureMethod
           consumerKey:(NSString *)consumerKey
        consumerSecret:(NSString *)consumerSecret
           callbackURL:(NSString *)callbackURL
{
    NSAssert(consumerKey, @"Consumer Key cannot be null");
    NSAssert(consumerSecret, @"Consumer Secret cannot be null");
    
	self = [super initWithBaseURL:[NSURL URLWithString:hostName]];
    
    if (self) {
        self.consumerSecret = consumerSecret;
		self.consumerKey = consumerKey;
        self.callbackURL = callbackURL;
        self.signatureMethod = signatureMethod;
        
        self.oAuthValues = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        oauthVersion, @"oauth_version",
                        oauthSignatureMethodName[self.signatureMethod], @"oauth_signature_method",
                        consumerKey, @"oauth_consumer_key",
                        @"", @"oauth_token",
                        @"", @"oauth_verifier",
                        @"", @"oauth_callback",
                        @"", @"oauth_signature",
                        @"", @"oauth_timestamp",
                        @"", @"oauth_nonce",
                        @"", @"realm",
                        nil];
        
        [self resetOAuthToken];
    }
    
    return self;
}

- (id)initWithHostName:(NSString *)hostName
    customHeaderFields:(NSDictionary *)headers
       signatureMethod:(IAOAuthSignatureMethod)signatureMethod
           consumerKey:(NSString *)consumerKey
        consumerSecret:(NSString *)consumerSecret
{
    return [self initWithHostName:hostName
               customHeaderFields:headers
                  signatureMethod:signatureMethod
                      consumerKey:consumerKey
                   consumerSecret:consumerSecret
                      callbackURL:nil];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)theParameters {
	NSAssert(self.oAuthValues && self.consumerKey && self.consumerSecret, @"Please use an initializer with Consumer Key and Consumer Secret.");
	
	NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:theParameters];
	[request setTimeoutInterval:15];
	
	// Generate timestamp and nonce values
	[self.oAuthValues setValue:AFURLEncodedStringFromStringWithEncoding([NSString stringWithFormat:@"%d", time(NULL)], self.stringEncoding) forKey:@"oauth_timestamp"];
	[self.oAuthValues setValue:AFURLEncodedStringFromStringWithEncoding([NSString uniqueString], self.stringEncoding) forKey:@"oauth_nonce"];
	
	NSDictionary *parameters = [NSMutableDictionary dictionary];
	[self.oAuthValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([key hasPrefix:@"oauth_"]  && ![key isEqualToString:@"oauth_signature"] && obj && ![obj isEqualToString:@""]) {
			[parameters setValue:AFURLEncodedStringFromStringWithEncoding(obj, self.stringEncoding) forKey:AFURLEncodedStringFromStringWithEncoding(key, self.stringEncoding)];	
		}
	}];
	
	if ([theParameters count] > 0) {
		[parameters setValuesForKeysWithDictionary:theParameters];
	}
	
	// Create the signature base string
	NSString *queryString = [[[AFQueryStringFromParametersWithEncoding(parameters, self.stringEncoding) componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@"&"];
    NSString *signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@",
                                     [[request HTTPMethod] uppercaseString],
                                     AFURLEncodedStringFromStringWithEncoding([[[[request URL] absoluteString] componentsSeparatedByString:@"?"] objectAtIndex:0], self.stringEncoding),
                                     [queryString urlEncodedString]];
	
	
	// Generate the signature
    switch (self.signatureMethod) {
        case IAOAuthHMAC_SHA1:
            [parameters setValue:AFURLEncodedStringFromStringWithEncoding([self generateHMAC_SHA1SignatureFor:signatureBaseString], self.stringEncoding) forKey:@"oauth_signature"];
            break;
        default:
            [parameters setValue:AFURLEncodedStringFromStringWithEncoding([self generatePlaintextSignatureFor:signatureBaseString], self.stringEncoding) forKey:@"oauth_signature"];
            break;
    }
	
	NSArray *sortedComponents = [[AFQueryStringFromParametersWithEncoding(parameters, self.stringEncoding) componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *mutableComponents = [NSMutableArray array];
    for (NSString *component in sortedComponents) {
        NSArray *subcomponents = [component componentsSeparatedByString:@"="];
        [mutableComponents addObject:[NSString stringWithFormat:@"%@=\"%@\"", [subcomponents objectAtIndex:0], [subcomponents objectAtIndex:1]]];
    }
	
	NSString *oauthString = [NSString stringWithFormat:@"OAuth %@", [mutableComponents componentsJoinedByString:@", "]];
    
    [request addValue:oauthString forHTTPHeaderField:@"Authorization"];
	[request setHTTPShouldHandleCookies:NO];
	
	return request;
}

#pragma mark - OAuth Signature Generators
- (NSString *)generatePlaintextSignatureFor:(NSString *)baseString {
    return [NSString stringWithFormat:@"%@&%@", 
            self.consumerSecret != nil ? [self.consumerSecret urlEncodedString] : @"", 
            self.tokenSecret != nil ? [self.tokenSecret urlEncodedString] : @""];
}

- (NSString *)generateHMAC_SHA1SignatureFor:(NSString *)baseString {
    NSString *key = [self generatePlaintextSignatureFor:baseString];
	
	const char *keyBytes = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *baseStringBytes = [baseString cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char digestBytes[CC_SHA1_DIGEST_LENGTH];
    
	CCHmacContext ctx;
    CCHmacInit(&ctx, kCCHmacAlgSHA1, keyBytes, strlen(keyBytes));
	CCHmacUpdate(&ctx, baseStringBytes, strlen(baseStringBytes));
	CCHmacFinal(&ctx, digestBytes);
    
	NSData *digestData = [NSData dataWithBytes:digestBytes length:CC_SHA1_DIGEST_LENGTH];
	return [digestData base64EncodedString];
}


#pragma mark - Public Methods
- (BOOL)isAuthenticated { return (self.tokenType == IAOAuthAccessToken && self.token && self.tokenSecret); }
- (void)resetOAuthToken {
    self.tokenType = IAOAuthRequestToken;
    self.tokenSecret = nil;
	self.token = nil;
    self.verifier = nil;
    self.customValues = nil;
    
    [self.oAuthValues setValue:self.callbackURL forKey:@"oauth_callback"];
    [self.oAuthValues setValue:@"" forKey:@"oauth_verifier"];
    [self.oAuthValues setValue:@"" forKey:@"oauth_token"];
}

- (void)fillTokenWithResponseBody:(NSString *)body type:(IAOAuthTokenType)tokenType {
    NSArray *pairs = [body componentsSeparatedByString:@"&"];
	
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [elements objectAtIndex:0];
        NSString *value = [[elements objectAtIndex:1] urlDecodedString];
        
        if ([key isEqualToString:@"oauth_token"]) {
            [self.oAuthValues setValue:value forKey:@"oauth_token"];
			self.token = value;
        } else if ([key isEqualToString:@"oauth_token_secret"]) {
            self.tokenSecret = value;
        } else if ([key isEqualToString:@"oauth_verifier"]) {
            self.verifier = value;
        } else {
            [self.customValues setValue:value forKey:key];
        }
    }
    
    self.tokenType = tokenType;
    
    // If we already have an Access Token, no need to send the Verifier and Callback URL
    if (self.tokenType == IAOAuthAccessToken) {
        [self.oAuthValues setValue:nil forKey:@"oauth_callback"];
        [self.oAuthValues setValue:nil forKey:@"oauth_verifier"];
    } else {
        [self.oAuthValues setValue:self.callbackURL forKey:@"oauth_callback"];
        [self.oAuthValues setValue:self.verifier forKey:@"oauth_verifier"];
    }
}

- (void)setAccessToken:(NSString *)token secret:(NSString *)tokenSecret {
    NSAssert(token, @"Token cannot be null");
    NSAssert(tokenSecret, @"Token Secret cannot be null");
    
    [self resetOAuthToken];
    
    [self.oAuthValues setValue:token forKey:@"oauth_token"];
	self.token = token;
    self.tokenSecret = tokenSecret;
    self.tokenType = IAOAuthAccessToken;
	
    // Since we already have an Access Token, no need to send the Verifier and Callback URL
    [self.oAuthValues setValue:nil forKey:@"oauth_callback"];
    [self.oAuthValues setValue:nil forKey:@"oauth_verifier"];
}


#pragma mark - Keychain helpers
- (void)addToKeychainUsingName:(NSString *)inName andValue:(NSString *)inValue {
	NSString *serverName = [self.baseURL host];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *securityDomain = [self.baseURL host];
	NSString *uniqueName = [NSString stringWithFormat:@"%@.%@", bundleID, inName];
	SecKeychainItemRef existingKeychainItem = NULL;
	
	if ([self findValueFromKeychainUsingName:inName returningItem:&existingKeychainItem]) {
		// This is MUCH easier than updating the item attributes/data
		SecKeychainItemDelete(existingKeychainItem);
	}
	
	SecKeychainAddInternetPassword(NULL /* default keychain */,
								   [serverName length], [serverName UTF8String],
								   [securityDomain length], [securityDomain UTF8String],
								   [uniqueName length], [uniqueName UTF8String],	/* account name */
								   0, NULL,	/* path */
								   0,
								   'oaut'	/* OAuth, not an official OSType code */,
								   kSecAuthenticationTypeDefault,
								   [inValue length], [inValue UTF8String],
								   NULL);
}

- (NSString *)findValueFromKeychainUsingName:(NSString *)inName {
	return [self findValueFromKeychainUsingName:inName returningItem:NULL];
}

- (NSString *)findValueFromKeychainUsingName:(NSString *)inName returningItem:(SecKeychainItemRef *)outKeychainItemRef {
	NSString *foundPassword = nil;
	NSString *serverName = [self.baseURL host];
	NSString *securityDomain = [self.baseURL host];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	NSString *uniqueName = [NSString stringWithFormat:@"%@.%@", bundleID, inName];
	
	UInt32 passwordLength = 0;
	const char *passwordString = NULL;
	
	OSStatus status = SecKeychainFindInternetPassword(NULL	/* default keychain */,
													  [serverName length], [serverName UTF8String],
													  [securityDomain length], [securityDomain UTF8String],
													  [uniqueName length], [uniqueName UTF8String],
													  0, NULL,	/* path */
													  0,
													  kSecProtocolTypeAny,
													  kSecAuthenticationTypeAny,
													  (UInt32 *)&passwordLength,
													  (void **)&passwordString,
													  outKeychainItemRef);
	
	if (status == noErr && passwordLength) {
		NSData *passwordStringData = [NSData dataWithBytes:passwordString length:passwordLength];
		foundPassword = [[NSString alloc] initWithData:passwordStringData encoding:NSUTF8StringEncoding];
	}
	
	return [foundPassword autorelease];
}

- (void)removeValueFromKeychainUsingName:(NSString *)inName {
	SecKeychainItemRef aKeychainItem = NULL;
	
	[self findValueFromKeychainUsingName:inName returningItem:&aKeychainItem];
	
	if (aKeychainItem) {
		SecKeychainItemDelete(aKeychainItem);
	}
}

@end
