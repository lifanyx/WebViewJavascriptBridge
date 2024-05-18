#import "WebViewJavascriptBridge.h"

#if defined(supportsWKWebView)
#import "WKWebViewJavascriptBridge.h"
#endif

#if __has_feature(objc_arc_weak)
    #define WVJB_WEAK __weak
#else
    #define WVJB_WEAK __unsafe_unretained
#endif

@implementation WebViewJavascriptBridge {
    WVJB_WEAK WVJB_WEBVIEW_TYPE* _webView;
    WVJB_WEAK id _webViewDelegate;
    long _uniqueId;
    WebViewJavascriptBridgeBase *_base;
}

/* API
 *****/

+ (void)enableLogging {
    [WebViewJavascriptBridgeBase enableLogging];
}
+ (void)setLogMaxLength:(int)length {
    [WebViewJavascriptBridgeBase setLogMaxLength:length];
}

+ (instancetype)bridgeForWebView:(id)webView {
    return [self bridge:webView];
}
+ (instancetype)bridge:(id)webView {
#if defined supportsWKWebView
    if ([webView isKindOfClass:[WKWebView class]]) {
        return (WebViewJavascriptBridge*) [WKWebViewJavascriptBridge bridgeForWebView:webView];
    }
#endif
    if ([webView isKindOfClass:[WVJB_WEBVIEW_TYPE class]]) {
        WebViewJavascriptBridge* bridge = [[self alloc] init];
        [bridge _platformSpecificSetup:webView];
        return bridge;
    }
    [NSException raise:@"BadWebViewType" format:@"Unknown web view type."];
    return nil;
}

- (void)setWebViewDelegate:(WVJB_WEBVIEW_DELEGATE_TYPE*)webViewDelegate {
    _webViewDelegate = webViewDelegate;
}

- (void)send:(id)data {
    [self send:data responseCallback:nil];
}

- (void)send:(id)data responseCallback:(WVJBResponseCallback)responseCallback {
    [_base sendData:data responseCallback:responseCallback handlerName:nil];
}

- (void)callHandler:(NSString *)handlerName {
    [self callHandler:handlerName data:nil responseCallback:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data {
    [self callHandler:handlerName data:data responseCallback:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data responseCallback:(WVJBResponseCallback)responseCallback {
    [_base sendData:data responseCallback:responseCallback handlerName:handlerName];
}

- (void)registerHandler:(NSString *)handlerName handler:(WVJBHandler)handler {
    _base.messageHandlers[handlerName] = [handler copy];
}

- (void)removeHandler:(NSString *)handlerName {
    [_base.messageHandlers removeObjectForKey:handlerName];
}

- (void)disableJavscriptAlertBoxSafetyTimeout {
    [_base disableJavscriptAlertBoxSafetyTimeout];
}

/* Platform agnostic internals
 *****************************/

- (void)dealloc {
    [self _platformSpecificDealloc];
    _base = nil;
    _webView = nil;
    _webViewDelegate = nil;
}

- (NSString*) _evaluateJavascript:(NSString*)javascriptCommand {
    return [_webView evaluateJavaScript:javascriptCommand completionHandler:nil];
}

- (void) _platformSpecificSetup:(WVJB_WEBVIEW_TYPE*)webView {
    _webView = webView;
    _webView.navigationDelegate = self;
    _base = [[WebViewJavascriptBridgeBase alloc] init];
    _base.delegate = self;
}

- (void) _platformSpecificDealloc {
    _webView.navigationDelegate = nil;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView != _webView) { return; }
    
    __strong WVJB_WEBVIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [strongDelegate webView:webView didFinishNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (webView != _webView) { return; }
    
    __strong WVJB_WEBVIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [strongDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}

- (BOOL)webView:(WKWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(WKNavigationType)navigationType {
    if (webView != _webView) { return YES; }
    
    NSURL *url = [request URL];
    __strong WVJB_WEBVIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if ([_base isWebViewJavascriptBridgeURL:url]) {
        if ([_base isBridgeLoadedURL:url]) {
            [_base injectJavascriptFile];
        } else if ([_base isQueueMessageURL:url]) {
            NSString *messageQueueString = [self _evaluateJavascript:[_base webViewJavascriptFetchQueyCommand]];
            [_base flushMessageQueue:messageQueueString];
        } else {
            [_base logUnkownMessage:url];
        }
        return NO;
    } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        return [strongDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    } else {
        return YES;
    }
}

- (void)webViewDidStartLoad:(WKWebView *)webView {
    if (webView != _webView) { return; }
    
    __strong WVJB_WEBVIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [strongDelegate webViewDidStartLoad:webView];
    }
}

@end
