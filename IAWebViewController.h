//
//  IAWebViewController.h
//
//  Created by Ivan Ablamskyi on 1/25/12.
//  Copyright (c) 2012 Coppertino Inc. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@protocol IAWebViewControllerDelegate;

@interface IAWebViewController : NSViewController {
	NSProgressIndicator *_progressIndicator;
	NSButton *_cancelButton;
	WebView *_webView;
	NSURL *_currentURL;
	id <IAWebViewControllerDelegate> _delegate;
	id _popoverController;
	NSView *_popupParent;

}

- (id)initWithURL:(NSURL *)theURL;
- (id)initWithURL:(NSURL *)theURL andDelegate:(id <IAWebViewControllerDelegate> )aDelegate;
- (id)initWithURL:(NSURL *)theURL andDelegate:(id <IAWebViewControllerDelegate> )aDelegate andParentView:(NSView *)theParentView;

- (IBAction)cancelAction:(id)sender;

@end


@protocol IAWebViewControllerDelegate <NSObject>
@required

- (void)webViewDidPopup;
- (void)dismissWebView;
- (BOOL)handleURL:(NSURL *)theURL;

@end