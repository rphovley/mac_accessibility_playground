#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

// Define the callback type
typedef void (*WindowChangeCallback)(const char *app_name,
                                     const char *window_title,
                                     const char *bundle_id, const char *url);

// Define a simple struct to hold window information
typedef struct {
  char *app_name;
  char *window_title;
  char *bundle_id;
  char *url;
} WindowTitle;

// Forward declaration
void free_window_title(WindowTitle *window_title);

// Simple wrapper for AXUIElement
@interface AccessibilityElement : NSObject
@property(nonatomic) AXUIElementRef axUIElement;

- (instancetype)initWithAXUIElement:(AXUIElementRef)element;
- (BOOL)addObserver:(AXObserverRef)observer
       notification:(CFStringRef)notification
           callback:(AXObserverCallback)callback
           userData:(void *)userData;
- (void)removeObserver:(AXObserverRef)observer
          notification:(CFStringRef)notification;
@end

@implementation AccessibilityElement

- (instancetype)initWithAXUIElement:(AXUIElementRef)element {
  self = [super init];
  if (self) {
    _axUIElement = CFRetain(element);
  }
  return self;
}

- (void)dealloc {
  if (_axUIElement) {
    CFRelease(_axUIElement);
  }
}

- (BOOL)addObserver:(AXObserverRef)observer
       notification:(CFStringRef)notification
           callback:(AXObserverCallback)callback
           userData:(void *)userData {
  AXError error =
      AXObserverAddNotification(observer, _axUIElement, notification, userData);
  return (error == kAXErrorSuccess);
}

- (void)removeObserver:(AXObserverRef)observer
          notification:(CFStringRef)notification {
  AXObserverRemoveNotification(observer, _axUIElement, notification);
}

@end

// Window observer class
@interface WindowObserver : NSObject
@property(nonatomic, strong) NSMutableDictionary *windowObservers;
@property(nonatomic) AXObserverRef currentAppObserver;
@property(nonatomic, strong) AccessibilityElement *currentAppElement;
@property(nonatomic, assign) WindowChangeCallback callback;
@property(nonatomic, assign) BOOL isObserving;
@property(nonatomic, strong) id appSwitchObserver;
@property(nonatomic, strong) NSThread *observerThread;

+ (instancetype)sharedObserver;
- (void)startObservingWithCallback:(WindowChangeCallback)callback;
- (void)stopObserving;
- (BOOL)isObserving;
@end

@implementation WindowObserver

+ (instancetype)sharedObserver {
  static WindowObserver *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[WindowObserver alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _windowObservers = [NSMutableDictionary dictionary];
    _isObserving = NO;
  }
  return self;
}

- (void)dealloc {
  [self stopObserving];
}

// Callback for window title changes
static void windowTitleCallback(AXObserverRef observer, AXUIElementRef element,
                                CFStringRef notification, void *contextData) {
  NSLog(@"Window title changed on thread: %@ (isMainThread: %@)",
        [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  WindowObserver *self = (__bridge WindowObserver *)contextData;
  [self handleWindowTitleChange:element];
}

// Callback for focused window changes
static void focusedWindowCallback(AXObserverRef observer,
                                  AXUIElementRef element,
                                  CFStringRef notification, void *contextData) {
  NSLog(@"Focused window changed");
  NSLog(@"Current thread: %@ (isMainThread: %@)", [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  WindowObserver *self = (__bridge WindowObserver *)contextData;
  [self handleFocusedWindowChange:element];
}

- (void)handleWindowTitleChange:(AXUIElementRef)element {
  [self notifyWindowChange:element];
}

- (void)handleFocusedWindowChange:(AXUIElementRef)element {
  // Get the focused window
  AXUIElementRef focusedWindow = NULL;
  AXError error = AXUIElementCopyAttributeValue(
      element, kAXFocusedWindowAttribute, (CFTypeRef *)&focusedWindow);

  if (error != kAXErrorSuccess || focusedWindow == NULL) {
    NSLog(@"Error getting focused window: %d", error);
    return;
  }

  [self observeWindowTitleChanges:focusedWindow];
  [self notifyWindowChange:focusedWindow];

  CFRelease(focusedWindow);
}

- (void)observeWindowTitleChanges:(AXUIElementRef)window {
  // Create a unique identifier for this window
  NSValue *windowRef = [NSValue valueWithPointer:(void *)window];

  // Check if we're already observing this window
  if (![_windowObservers objectForKey:windowRef]) {
    // Create a new observer for this window
    pid_t pid;
    AXUIElementGetPid(window, &pid);

    AXObserverRef windowObserver = NULL;
    AXError error = AXObserverCreate(pid, windowTitleCallback, &windowObserver);

    if (error == kAXErrorSuccess && windowObserver != NULL) {
      // Register for title changes on this specific window
      error = AXObserverAddNotification(windowObserver, window,
                                        kAXTitleChangedNotification,
                                        (__bridge void *)self);

      if (error == kAXErrorSuccess) {
        // Add the observer to the run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           AXObserverGetRunLoopSource(windowObserver),
                           kCFRunLoopDefaultMode);

        // Store the observer
        [_windowObservers setObject:(__bridge id)(windowObserver)
                             forKey:windowRef];
      } else {
        NSLog(@"Error adding title notification to window: %d", error);
        CFRelease(windowObserver);
      }
    }
  }
}

- (void)notifyWindowChange:(AXUIElementRef)window {
  if (!_callback) {
    return;
  }

  // Get window information
  pid_t pid;
  if (AXUIElementGetPid(window, &pid) != kAXErrorSuccess) {
    return;
  }

  NSRunningApplication *app =
      [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
  if (!app) {
    return;
  }

  // Get window title
  CFStringRef titleRef = NULL;
  AXUIElementCopyAttributeValue(window, kAXTitleAttribute,
                                (CFTypeRef *)&titleRef);
  NSString *title = titleRef ? (__bridge_transfer NSString *)titleRef : @"";

  // Create window info struct
  WindowTitle *windowInfo = malloc(sizeof(WindowTitle));
  windowInfo->app_name = strdup([app.localizedName UTF8String]);
  windowInfo->window_title = strdup([title UTF8String]);
  windowInfo->bundle_id = strdup([app.bundleIdentifier UTF8String]);
  windowInfo->url =
      NULL; // We don't have URL information in this simple implementation

  // Call the callback
  _callback(windowInfo->app_name, windowInfo->window_title,
            windowInfo->bundle_id, windowInfo->url);

  // Free the window info
  free_window_title(windowInfo);
}

- (BOOL)startObservingApp:(pid_t)pid {
  NSLog(@"startObservingApp called on thread: %@ (isMainThread: %@)",
        [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  // Clean up previous app observer if it exists
  [self cleanupCurrentAppObserver];

  // Create a new observer for the application
  AXError error =
      AXObserverCreate(pid, focusedWindowCallback, &_currentAppObserver);
  if (error != kAXErrorSuccess) {
    NSLog(@"Error creating observer: %d", error);
    return NO;
  }

  // Create a reference to the application's UI element
  AXUIElementRef appElement = AXUIElementCreateApplication(pid);
  _currentAppElement =
      [[AccessibilityElement alloc] initWithAXUIElement:appElement];
  CFRelease(appElement); // AccessibilityElement retains it

  // Register for focused window changed notification
  BOOL success =
      [_currentAppElement addObserver:_currentAppObserver
                         notification:kAXFocusedWindowChangedNotification
                             callback:focusedWindowCallback
                             userData:(__bridge void *)self];

  if (!success) {
    [self cleanupCurrentAppObserver];
    return NO;
  }

  // Add the observer to the run loop
  CFRunLoopAddSource(CFRunLoopGetCurrent(),
                     AXObserverGetRunLoopSource(_currentAppObserver),
                     kCFRunLoopDefaultMode);

  // Trigger the callback once to observe the currently focused window
  focusedWindowCallback(_currentAppObserver, _currentAppElement.axUIElement,
                        kAXFocusedWindowChangedNotification,
                        (__bridge void *)self);

  NSLog(@"Observing process %d for window focus changes", pid);
  return YES;
}

- (void)startObservingWithCallback:(WindowChangeCallback)callback {
  NSLog(@"startObservingWithCallback on thread: %@ (isMainThread: %@)",
        [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  if (_isObserving) {
    [self stopObserving];
  }

  _callback = callback;
  _isObserving = YES;

  // Create a new thread to run the observation code
  _observerThread = [[NSThread alloc] initWithBlock:^{
    @autoreleasepool {
      NSLog(@"Observer thread started: %@ (isMainThread: %@)",
            [NSThread currentThread].name,
            [NSThread isMainThread] ? @"YES" : @"NO");

      // First observe the currently focused application
      NSRunningApplication *currentApp =
          [[NSWorkspace sharedWorkspace] frontmostApplication];
      if (currentApp) {
        NSLog(@"Starting with app: %@ (Bundle ID: %@)",
              currentApp.localizedName, currentApp.bundleIdentifier);
        BOOL success = [self startObservingApp:currentApp.processIdentifier];
        NSLog(@"startObservingApp result: %@",
              success ? @"SUCCESS" : @"FAILURE");
      }

      NSLog(@"Starting app switch observer");
      // Register for workspace notifications to detect app switching
      __weak typeof(self) weakSelf = self;

      // Make sure we're on the main thread when setting up the notification
      // observer
      dispatch_async(dispatch_get_main_queue(), ^{
        // Remove any existing observer first
        if (self->_appSwitchObserver) {
          [[NSWorkspace sharedWorkspace].notificationCenter
              removeObserver:self->_appSwitchObserver];
          self->_appSwitchObserver = nil;
        }

        // Add the new observer
        self->_appSwitchObserver =
            [[NSWorkspace sharedWorkspace].notificationCenter
                addObserverForName:NSWorkspaceDidActivateApplicationNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(NSNotification *notification) {
                          NSLog(@"App switch notification received on thread: "
                                @"%@ (isMainThread: %@)",
                                [NSThread currentThread].name,
                                [NSThread isMainThread] ? @"YES" : @"NO");

                          NSRunningApplication *app =
                              notification.userInfo[NSWorkspaceApplicationKey];
                          NSLog(@"Focused app changed to: %@ (Bundle ID: %@)",
                                app.localizedName, app.bundleIdentifier);

                          BOOL success = [weakSelf
                              startObservingApp:app.processIdentifier];
                          NSLog(@"startObservingApp result: %@",
                                success ? @"SUCCESS" : @"FAILURE");
                        }];

        NSLog(@"App switch observer registered: %@", self->_appSwitchObserver);
      });

      // Run the run loop on this thread to receive notifications
      NSLog(@"Starting run loop on observer thread");
      CFRunLoopRun();
    }
  }];

  // Set thread name for debugging purposes
  [_observerThread setName:@"WindowObserverThread"];

  // Start the thread
  [_observerThread start];
}

- (void)stopObserving {
  if (!_isObserving) {
    return;
  }

  // Remove app switch observer
  if (_appSwitchObserver) {
    [[NSWorkspace sharedWorkspace].notificationCenter
        removeObserver:_appSwitchObserver];
    _appSwitchObserver = nil;
  }

  // Clean up app observer
  [self cleanupCurrentAppObserver];

  // Clean up window observers
  for (NSValue *key in _windowObservers) {
    AXObserverRef observer =
        (__bridge AXObserverRef)([_windowObservers objectForKey:key]);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                          AXObserverGetRunLoopSource(observer),
                          kCFRunLoopDefaultMode);
  }
  [_windowObservers removeAllObjects];

  // Stop the observer thread
  if (_observerThread) {
    CFRunLoopStop(CFRunLoopGetCurrent());
    _observerThread = nil;
  }

  _callback = NULL;
  _isObserving = NO;
}

- (void)cleanupCurrentAppObserver {
  if (_currentAppElement && _currentAppObserver) {
    [_currentAppElement removeObserver:_currentAppObserver
                          notification:kAXFocusedWindowChangedNotification];
    _currentAppElement = nil;

    CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                          AXObserverGetRunLoopSource(_currentAppObserver),
                          kCFRunLoopDefaultMode);
    CFRelease(_currentAppObserver);
    _currentAppObserver = NULL;
  }
}

- (BOOL)isObserving {
  return _isObserving;
}

@end

// Helper function to free window title struct
void free_window_title(WindowTitle *window_title) {
  if (window_title) {
    if (window_title->app_name)
      free(window_title->app_name);
    if (window_title->window_title)
      free(window_title->window_title);
    if (window_title->bundle_id)
      free(window_title->bundle_id);
    if (window_title->url)
      free(window_title->url);
    free(window_title);
  }
}

// Example callback function for testing
static void windowChangeCallback(const char *app_name, const char *window_title,
                                 const char *bundle_id, const char *url) {
  NSLog(@"Window changed - App: %s, Title: %s, Bundle: %s, URL: %s", app_name,
        window_title, bundle_id, url ? url : "(none)");
}

// C API for Rust to call
#ifdef __cplusplus
extern "C" {
#endif

// Start observing window changes with the given callback
void start_window_observing(WindowChangeCallback callback) {
  @autoreleasepool {
    [[WindowObserver sharedObserver] startObservingWithCallback:callback];
  }
}

// Stop observing window changes
void stop_window_observing() {
  @autoreleasepool {
    [[WindowObserver sharedObserver] stopObserving];
  }
}

// Check if currently observing
bool is_window_observing() {
  @autoreleasepool {
    return [[WindowObserver sharedObserver] isObserving];
  }
}

#ifdef __cplusplus
}
#endif

// Remove or comment out the main function since we're building a library
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSLog(@"Main function running on thread: %@ (isMainThread: %@)",
          [NSThread currentThread].name,
          [NSThread isMainThread] ? @"YES" : @"NO");

    // Create a new thread to run the observation code
    NSThread *observerThread = [[NSThread alloc] initWithBlock:^{
      @autoreleasepool {
        NSLog(@"Observer thread started: %@ (isMainThread: %@)",
              [NSThread currentThread].name,
              [NSThread isMainThread] ? @"YES" : @"NO");

        // Start observing with our WindowObserver class
        WindowObserver *observer = [WindowObserver sharedObserver];
        [observer startObservingWithCallback:windowChangeCallback];

        // Run the run loop on this thread to receive notifications
        NSLog(@"Starting run loop on observer thread");
        CFRunLoopRun();

        // Clean up (this won't be reached unless the run loop isstopped)
        [observer stopObserving];
      }
    }];

    // Set thread name for debugging purposes
    [observerThread setName:@"WindowObserverThread"];

    // Start the thread
    [observerThread start];

    // Keep the main thread alive
    NSLog(@"Starting run loop on main thread");
    [[NSRunLoop currentRunLoop] run];
  }

  return 0;
}