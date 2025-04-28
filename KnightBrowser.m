// KnightBrowser.m - Enhanced macOS browser with dark mode, bookmarks, history, downloads
// Compile with: clang -fobjc-arc -framework Cocoa -framework WebKit -o KnightBrowser KnightBrowser.m

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface BrowserAppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, NSTextFieldDelegate>
@property (strong, nonatomic) NSWindow            *window;
@property (strong, nonatomic) WKWebView          *webView;
@property (strong, nonatomic) NSTextField        *urlField;
@property (strong, nonatomic) NSButton           *backButton;
@property (strong, nonatomic) NSButton           *forwardButton;
@property (strong, nonatomic) NSButton           *reloadButton;
@property (strong, nonatomic) NSButton           *homeButton;
@property (strong, nonatomic) NSButton           *darkModeButton;
@property (strong, nonatomic) NSButton           *bookmarksButton;
@property (strong, nonatomic) NSButton           *downloadsButton;
@property (strong, nonatomic) NSButton           *historyButton;
@property (assign, nonatomic) BOOL               darkModeEnabled;
@property (strong, nonatomic) NSMutableArray<NSURL *> *bookmarksArray;
@property (strong, nonatomic) NSMutableArray<NSURL *> *historyArray;
@end

@implementation BrowserAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Set up as proper GUI application
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    // Initialize storage
    self.bookmarksArray = [NSMutableArray new];
    self.historyArray   = [NSMutableArray new];
    
    // Create main window
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    NSRect windowFrame = NSMakeRect(
        screenFrame.size.width/4,
        screenFrame.size.height/4,
        screenFrame.size.width/2,
        screenFrame.size.height/2
    );
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
        styleMask:(NSWindowStyleMaskTitled |
                   NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable |
                   NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered
        defer:NO];
    self.window.title = @"Knight Browser";
    [self.window setMinSize:NSMakeSize(500, 400)];

    // Toolbar
    CGFloat toolbarHeight = 50;
    NSView *contentView = self.window.contentView;
    NSRect contentFrame = contentView.frame;
    NSView *toolbarView = [[NSView alloc] initWithFrame:
        NSMakeRect(0, contentFrame.size.height - toolbarHeight,
                   contentFrame.size.width, toolbarHeight)];
    toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    toolbarView.wantsLayer = YES;
    toolbarView.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    [contentView addSubview:toolbarView];

    // Buttons + URL field
    CGFloat bw = 30, bs = 10, x = bs;
    #define ADD_BTN(var, img, sel, tip) \
      var = [self createToolbarButtonWithFrame:NSMakeRect(x,10,bw,bw) \
                                       image:[NSImage imageNamed:img] \
                                      action:@selector(sel) \
                                     toolTip:tip]; \
      [toolbarView addSubview:var]; x += bw + bs;

    ADD_BTN(self.homeButton,           NSImageNameHomeTemplate,          goHome:,      @"Home")
    ADD_BTN(self.backButton,           NSImageNameGoLeftTemplate,        goBack:,      @"Back")
    self.backButton.enabled = NO;
    ADD_BTN(self.forwardButton,        NSImageNameGoRightTemplate,       goForward:,   @"Forward")
    self.forwardButton.enabled = NO;
    ADD_BTN(self.reloadButton,         NSImageNameRefreshTemplate,       reload:,      @"Reload")
    ADD_BTN(self.bookmarksButton,      NSImageNameBookmarksTemplate,     showBookmarks:, @"Bookmarks")
    
    // History (fallback icon)
    NSImage *histImg = [NSImage imageNamed:NSImageNameIChatTheaterTemplate]
                     ?: [NSImage imageNamed:NSImageNameAdvanced];
    self.historyButton = [self createToolbarButtonWithFrame:NSMakeRect(x,10,bw,bw)
                                                     image:histImg
                                                    action:@selector(showHistory:)
                                                   toolTip:@"History"];
    [toolbarView addSubview:self.historyButton]; x += bw + bs;

    // Downloads (fallback icon)
    NSImage *dlImg = [NSImage imageNamed:NSImageNameFolder]
                   ?: [NSImage imageNamed:NSImageNameNetwork];
    self.downloadsButton = [self createToolbarButtonWithFrame:NSMakeRect(x,10,bw,bw)
                                                       image:dlImg
                                                      action:@selector(showDownloads:)
                                                     toolTip:@"Downloads"];
    [toolbarView addSubview:self.downloadsButton]; x += bw + bs;

    ADD_BTN(self.darkModeButton,       NSImageNameColorPanel,            toggleDarkMode:, @"Toggle Dark Mode")

    // URL Entry
    self.urlField = [[NSTextField alloc] initWithFrame:
        NSMakeRect(x,10, contentFrame.size.width - x - bs, 30)];
    self.urlField.placeholderString = @"Enter URL...";
    self.urlField.bezelStyle = NSTextFieldRoundedBezel;
    self.urlField.target     = self;
    self.urlField.action     = @selector(loadURL:);
    self.urlField.delegate   = self;
    self.urlField.autoresizingMask = NSViewWidthSizable;
    [toolbarView addSubview:self.urlField];

    // WebView
    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    self.webView = [[WKWebView alloc] initWithFrame:
        NSMakeRect(0,0, contentFrame.size.width,
                   contentFrame.size.height - toolbarHeight)
                                         configuration:cfg];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate         = self;
    self.webView.autoresizingMask   = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:self.webView];

    // Load home, show window, focus URL
    [self goHome:nil];
    [self.window makeFirstResponder:self.urlField];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    // Dark‐mode initial state
    if (@available(macOS 10.14,*)) {
        self.darkModeEnabled = [self.window.effectiveAppearance.name
                                isEqualToString:NSAppearanceNameDarkAqua];
    }
}

- (NSButton *)createToolbarButtonWithFrame:(NSRect)frame
                                     image:(NSImage *)image
                                    action:(SEL)action
                                   toolTip:(NSString *)toolTip
{
    NSButton *btn = [[NSButton alloc] initWithFrame:frame];
    btn.image      = image;
    btn.bezelStyle = NSBezelStyleTexturedRounded;
    btn.target     = self;
    btn.action     = action;
    btn.toolTip    = toolTip;
    return btn;
}

#pragma mark – Actions

- (void)goHome:(id)sender {
    [self.webView loadRequest:
      [NSURLRequest requestWithURL:
        [NSURL URLWithString:@"https://www.google.com"]]];
}

- (void)loadURL:(id)sender {
    NSString *u = self.urlField.stringValue;
    if (![u hasPrefix:@"http"]) u = [@"https://" stringByAppendingString:u];
    [self.webView loadRequest:
      [NSURLRequest requestWithURL:[NSURL URLWithString:u]]];
}

- (void)goBack:(id)sender    { if ([self.webView canGoBack])    [self.webView goBack];    }
- (void)goForward:(id)sender { if ([self.webView canGoForward]) [self.webView goForward]; }
- (void)reload:(id)sender    { [self.webView reload];            }

- (void)showBookmarks:(id)sender {
    NSAlert *dlg = [NSAlert new];
    dlg.messageText = @"Bookmarks";
    [dlg addButtonWithTitle:@"Add Current"];
    [dlg addButtonWithTitle:@"Open Bookmark"];
    [dlg addButtonWithTitle:@"Cancel"];
    switch ([dlg runModal]) {
        case NSAlertFirstButtonReturn: {
            NSURL *u = self.webView.URL; if (u) [self.bookmarksArray addObject:u];
            break;
        }
        case NSAlertSecondButtonReturn: {
            if (!self.bookmarksArray.count) {
                // replaced deprecated alertWithMessageText:...
                NSAlert *noBk = [[NSAlert alloc] init];
                noBk.messageText     = @"No bookmarks saved.";
                noBk.informativeText = @"";
                [noBk addButtonWithTitle:@"OK"];
                [noBk runModal];
                return;
            }
            NSAlert *a = [NSAlert new];
            a.messageText   = @"Open Bookmark";
            NSPopUpButton *popup = [[NSPopUpButton alloc]
                initWithFrame:NSMakeRect(0,0,350,24) pullsDown:NO];
            for (NSURL *u in self.bookmarksArray)
                [popup addItemWithTitle:u.absoluteString];
            a.accessoryView = popup;
            [a addButtonWithTitle:@"Open"];
            [a addButtonWithTitle:@"Cancel"];
            if ([a runModal] == NSAlertFirstButtonReturn) {
                [self.webView loadRequest:
                  [NSURLRequest requestWithURL:
                    [NSURL URLWithString:popup.titleOfSelectedItem]]];
            }
            break;
        }
        default: break;
    }
}

- (void)showHistory:(id)sender {
    if (!self.historyArray.count) {
        // replaced deprecated alertWithMessageText:...
        NSAlert *empty = [[NSAlert alloc] init];
        empty.messageText     = @"History is empty.";
        empty.informativeText = @"";
        [empty addButtonWithTitle:@"OK"];
        [empty runModal];
        return;
    }
    NSAlert *a = [NSAlert new];
    a.messageText = @"History";
    NSPopUpButton *popup = [[NSPopUpButton alloc]
        initWithFrame:NSMakeRect(0,0,350,24) pullsDown:NO];
    for (NSURL *u in self.historyArray)
        [popup addItemWithTitle:u.absoluteString];
    a.accessoryView = popup;
    [a addButtonWithTitle:@"Open"];
    [a addButtonWithTitle:@"Cancel"];
    if ([a runModal] == NSAlertFirstButtonReturn) {
        [self.webView loadRequest:
          [NSURLRequest requestWithURL:
            [NSURL URLWithString:popup.titleOfSelectedItem]]];
    }
}


- (void)showDownloads:(id)sender {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory,
                                                           NSUserDomainMask,
                                                           YES) firstObject];
    [[NSWorkspace sharedWorkspace] openFile:path];
}

- (void)toggleDarkMode:(id)sender {
    self.darkModeEnabled = !self.darkModeEnabled;
    if (@available(macOS 10.14,*)) {
        NSAppearance *ap = self.darkModeEnabled
            ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]
            : [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        self.window.appearance = ap;
        self.darkModeButton.toolTip =
          self.darkModeEnabled ? @"Toggle Light Mode" : @"Toggle Dark Mode";
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView*)wv didStartProvisionalNavigation:(WKNavigation*)nav {
    self.urlField.stringValue = wv.URL.absoluteString ?: @"";
}

- (void)webView:(WKWebView*)wv didFinishNavigation:(WKNavigation*)nav {
    // Update nav buttons
    self.backButton.enabled    = [wv canGoBack];
    self.forwardButton.enabled = [wv canGoForward];
    // Record history
    if (wv.URL) [self.historyArray addObject:wv.URL];
    // Update title
    [wv evaluateJavaScript:@"document.title"
          completionHandler:^(id title, NSError *err) {
        if ([title isKindOfClass:NSString.class]) {
            self.window.title = [NSString stringWithFormat:@"%@ - Knight Browser", title];
        }
    }];
}

- (void)webView:(WKWebView*)wv didFailNavigation:(WKNavigation*)nav withError:(NSError*)err {
    NSAlert *a = [NSAlert new];
    a.messageText       = @"Navigation Error";
    a.informativeText   = err.localizedDescription;
    [a addButtonWithTitle:@"OK"];
    [a runModal];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication      *app = [NSApplication sharedApplication];
        BrowserAppDelegate *del = [BrowserAppDelegate new];
        app.delegate = del;

        // App menu (Cmd+Q)
        NSMenu *mb     = [NSMenu new];
        NSMenuItem *mi = [NSMenuItem new];
        [mb addItem:mi];
        [NSApp setMainMenu:mb];
        NSMenu *am     = [NSMenu new];
        [mi setSubmenu:am];
        [am addItemWithTitle:@"Quit Knight Browser"
                     action:@selector(terminate:)
              keyEquivalent:@"q"];

        [app run];
    }
    return 0;
}
