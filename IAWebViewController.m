//
//  IAWebViewController.m
//
//  Created by Ivan Ablamskyi on 1/25/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "IAWebViewController.h"
#import "INPopoverController.h"

@interface IAWebViewController ( /* Private methods */ )

@property (assign) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign) IBOutlet NSButton *cancelButton;
@property (assign) IBOutlet WebView *webView;
@property (retain) NSURL *currentURL;
@property (assign) NSView *popupParent;
@property (assign) id <IAWebViewControllerDelegate> delegate;
@property (retain) id popoverController;

@end

@implementation IAWebViewController
@synthesize progressIndicator = _progressIndicator;
@synthesize cancelButton = _cancelButton;
@synthesize webView = _webView;
@synthesize currentURL = _currentURL;
@synthesize delegate = _delegate;
@synthesize popoverController = _popoverController;
@synthesize popupParent = _popupParent;

- (id)initWithURL:(NSURL *)theURL andDelegate:(id <IAWebViewControllerDelegate> )aDelegate andParentView:(NSView *)theParentView {
    self = [self initWithNibName:@"IAWebViewController" bundle:[NSBundle bundleForClass:[self class]]];
    
    if (self) {
        self.currentURL = theURL;
        self.delegate = aDelegate;
		self.popupParent = theParentView;
		
		if (theParentView) {
			// if we're running non lion, then use INPopopoverController as is
			if (IB_IS_RUNNING_ON_LION) {
				NSPopover *_popover = [[NSPopover alloc] init];
				// The popover retains us and we retain the popover. We drop the popover whenever it is closed to avoid a cycle.
				_popover.contentViewController = self;
				_popover.behavior = NSPopoverBehaviorApplicationDefined;
				_popover.delegate = (id <NSPopoverDelegate>)self;
				self.popoverController = _popover;
				[_popover release];
				[self loadView];
			}
			else {
				INPopoverController *popoverController = [[INPopoverController alloc] initWithContentViewController:self];
				popoverController.closesWhenPopoverResignsKey = NO;
				popoverController.color = [NSColor colorWithCalibratedWhite:1.0 alpha:0.8];
				popoverController.borderColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.5];
				popoverController.borderWidth = 1.0;
				popoverController.delegate = (id <INPopoverControllerDelegate>)self;

				self.popoverController = popoverController;
				[popoverController release];
			}
		}
		else {
//			there are no parent view, should be simple window or panel
//			have been implempented in future
		}
    }
    
    return self;
}

- (id)initWithURL:(NSURL *)theURL andDelegate:(id<IAWebViewControllerDelegate>)aDelegate {
	return [self initWithURL:theURL andDelegate:aDelegate andParentView:nil];
}

- (id)initWithURL:(NSURL *)theURL {
	return [self initWithURL:theURL andDelegate:nil];
}

- (void)awakeFromNib {
	[self.webView setShouldCloseWithWindow:YES];
	[self.webView setMainFrameURL:[self.currentURL absoluteString]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelAction:) name:NSWindowDidResignKeyNotification object:self.popupParent.window];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.progressIndicator = nil;
	self.cancelButton = nil;
	self.webView = nil;
	self.currentURL = nil;
	self.delegate = nil;
	[super dealloc];
}

- (IBAction)cancelAction:(id)sender {
	if ([self.popoverController isKindOfClass:[INPopoverController class]]) {
		INPopoverController *popoverController = self.popoverController;
		[popoverController closePopover:nil];
	} 
	else if (self.popoverController && [self.popoverController isKindOfClass:NSClassFromString(@"NSPopover")]) {
		[self.popoverController performClose:NSApp];
	}
	
	[self.delegate performSelector: @selector(dismissWebView)];

}

#pragma mark - WebView deleagate
- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame {
	// Because of facebook redirects and OAuth 2.0 differnet hardcode url to compare
	if ([sender.mainFrame isEqualTo:frame] && [sender.mainFrameURL hasPrefix:@"https://m.facebook.com/dialog/"]) {
		self.currentURL = [NSURL URLWithString:sender.mainFrameURL];
	}

}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame; {
	if ([sender.mainFrame isEqualTo:frame] && [[NSURL URLWithString:sender.mainFrameURL] isEqualTo:self.currentURL]){
		if ([[self.currentURL host] isEqualToString:@"api.twitter.com"]) {
			NSRect newRect = NSInsetRect([[[self.popoverController contentViewController] view] frame], 0, -40);
			[[[self.popoverController contentViewController] view] setFrame:newRect];
		}
		if ([self.popoverController isKindOfClass:[INPopoverController class]]) {
			INPopoverController *popoverController = self.popoverController;
			if ([popoverController popoverIsVisible]) 
				return;
			[popoverController presentPopoverFromRect:[self.popupParent bounds] inView:self.popupParent preferredArrowDirection:NSMinYEdge anchorsToPositionView:YES];
			[self.delegate webViewDidPopup];
		}
		else if (self.popoverController && [self.popoverController isKindOfClass:NSClassFromString(@"NSPopover")]) {
			[self.popoverController showRelativeToRect:[self.popupParent bounds] ofView:self.popupParent preferredEdge:NSMinYEdge];
			[self.delegate webViewDidPopup];
		}
	}
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {
	if (![self.popupParent.window isVisible]) {
		[self.delegate dismissWebView];
		return;
	}
	
	DOMHTMLInputElement *pressedButton = [[actionInformation valueForKey:WebActionElementKey] valueForKey:WebElementDOMNodeKey];

//	NSLog(@"%@ finish load action %@ frameL %@", webView, actionInformation, frame);

	if ((pressedButton && [pressedButton isKindOfClass:[DOMHTMLInputElement class]] && [pressedButton.name isEqualToString:@"deny"]) || 
		[self.delegate handleURL:[actionInformation valueForKey:WebActionOriginalURLKey]]) {
		if ([self.popoverController isKindOfClass:[INPopoverController class]]) {
			INPopoverController *popoverController = self.popoverController;
			[popoverController closePopover:nil];
		} 
		else if (self.popoverController && [self.popoverController isKindOfClass:NSClassFromString(@"NSPopover")]) {
			[self.popoverController performClose:NSApp];
		}
		
		[listener ignore];
	}
	else {
		[listener use];
	}

}

- (void)popoverDidClose:(NSNotification *)notification; {
	[self.delegate dismissWebView];
}

@end
