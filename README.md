# ShareKit for OSX

**ShareKit for OSX** is extention for existed AFNetworing that provide in-app sharing like in ios devices. 

## Overview
Curent kit is based on AFNetwroking kit and main idea is on create universal sharing/authorization process that could help to developers comunicate with OAuth based services. It is strage to share some thing like open share url, in time when almost each online service provide posibility to use any sort of RestAPI. I know, that twitter preffered xAuht scheme, but I have no big trust to input any private data into application, instead I dont see trusted form. In this case webview preffered. All auhorization data will store in the system keychain, and some one can say:
> brrrr… why… user probaby do not like give access to kc.

But I'm agree, that experiance should unified.

## Usage
1. Include sources into your project (this step required that AFNetworking is already included).
2. If you applicaion want run 10.6+ you have inlucde INPopoverController. 
3. Define access to serivces you need:
<!--			#define TW_CONSUMER_KEY @"TWITTER KEY"
			#define TW_CONSUMER_SECRET @"TWITTER SECRET"
			#define FB_APP_KEY @"FACE BOOK APP"
			#define FB_APP_SECRET @"FACE BOOK SECRET"
-->
4. Make instance and send request:

		if (!self.facebook) {
			self.facebook = [[[IAFacebookEngine alloc] initWithDelegate:self] autorelease];
			self.facebook.perms = [NSArray arrayWithObjects: @"read_stream", @"publish_stream", nil];
		}
		
		NSString *message = @"some message"
		NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
						message, @"message",
						@"Your app", @"from",
						[[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
									   @"http://sharelink", @"link", 
									   @"Link name", @"name", nil]] JSONRepresentation], @"actions",
						[[NSDictionary dictionaryWithObjectsAndKeys: @"AppName", @"name", FB_APP_KEY, @"id", nil] JSONRepresentation], @"application",
						nil];
		[self.facebook postGraphTo:@"/me/feed/" withParams:params withCompletionBlock:^(NSError *error, id json) {
			if (error) {
				NSLog(@"fb:error:%@", error);
			}
			else  {
				[[NSSound soundNamed:@"facebooksound"] play];
			}
		}];

5. Implement delegate methods:

		- (void)facebookEngine:(IAFacebookEngine *)engine needsToOpenURL:(NSURL *)url {
			self.urlBlock = ^(NSURL *theURL) {
					if ([[theURL absoluteString] hasPrefix:self.facebook.callbackURL]) {
						if ([theURL.query hasPrefix:@"denied"]) {
							[self.facebook cancelAuthentication];
							self.facebook = nil;
						} else {
							[self.facebook resumeAuthenticationFlowWithURL:theURL];
						}
						self.closeBlock = nil;
						self.urlBlock = nil;
						return YES;
					}
					
				return NO;
				};
				
				self.webView = [[[IAWebViewController alloc] initWithURL:url andDelegate:self andParentView:self.webviewParent] autorelease];
		}
		

## Licensing
*ShareKit for OSX* is licensed under the BSD license. 

## Credits 
Thanks for inspiring [PhFacebook](https://github.com/philippec/PhFacebook) project and [INPopover](https://github.com/indragiek/INPopoverController).

