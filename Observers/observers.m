#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

// Global variables to track current state
static NSMutableDictionary *gWindowObservers = nil;
static AXObserverRef gCurrentAppObserver = NULL;
static AXUIElementRef gCurrentAppElement = NULL;

// Callback function for window title changes
void windowTitleCallback(AXObserverRef observer, AXUIElementRef element,
                         CFStringRef notification, void *contextData) {
  CFTypeRef windowTitle;
  AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &windowTitle);
  if (windowTitle) {
    NSLog(@"Window title changed to: %@", windowTitle);
    CFRelease(windowTitle);
  }
}

// Callback function for focused window changes
void focusedWindowCallback(AXObserverRef observer, AXUIElementRef element,
                           CFStringRef notification, void *contextData) {
  NSLog(@"Focused window changed");
  NSLog(@"Current thread: %@ (isMainThread: %@)", [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  // Get the focused window
  AXUIElementRef focusedWindow = NULL;
  AXError error = AXUIElementCopyAttributeValue(
      element, kAXFocusedWindowAttribute, (CFTypeRef *)&focusedWindow);

  if (error != kAXErrorSuccess || focusedWindow == NULL) {
    NSLog(@"Error getting focused window: %d", error);
    return;
  }

  // Get the window title
  CFTypeRef windowTitle;
  AXUIElementCopyAttributeValue(focusedWindow, kAXTitleAttribute, &windowTitle);
  if (windowTitle) {
    NSLog(@"Focused window title: %@", windowTitle);
    CFRelease(windowTitle);
  }

  // Create a unique identifier for this window
  NSValue *windowRef = [NSValue valueWithPointer:(void *)focusedWindow];

  // Check if we're already observing this window
  if (![gWindowObservers objectForKey:windowRef]) {
    // Create a new observer for this window
    pid_t pid;
    AXUIElementGetPid(focusedWindow, &pid);

    AXObserverRef windowObserver = NULL;
    error = AXObserverCreate(pid, windowTitleCallback, &windowObserver);

    if (error == kAXErrorSuccess && windowObserver != NULL) {
      // Register for title changes on this specific window
      error = AXObserverAddNotification(windowObserver, focusedWindow,
                                        kAXTitleChangedNotification, NULL);

      if (error == kAXErrorSuccess) {
        // Add the observer to the run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           AXObserverGetRunLoopSource(windowObserver),
                           kCFRunLoopDefaultMode);

        // Store the observer
        [gWindowObservers setObject:(__bridge id)(windowObserver)
                             forKey:windowRef];
        // NSLog(@"Now observing title changes for window: %@", windowTitle);
      } else {
        NSLog(@"Error adding title notification to window: %d", error);
        CFRelease(windowObserver);
      }
    } else {
      NSLog(@"Error creating window observer: %d", error);
    }
  }

  CFRelease(focusedWindow);
}

// Function to start observing window focus changes for a specific application
BOOL startObservingApp(pid_t pid) {
  NSLog(@"startObservingApp called on thread: %@ (isMainThread: %@)",
        [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  // Clean up previous app observer if it exists
  if (gCurrentAppObserver != NULL) {
    if (gCurrentAppElement != NULL) {
      AXObserverRemoveNotification(gCurrentAppObserver, gCurrentAppElement,
                                   kAXFocusedWindowChangedNotification);
      CFRelease(gCurrentAppElement);
      gCurrentAppElement = NULL;
    }
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                          AXObserverGetRunLoopSource(gCurrentAppObserver),
                          kCFRunLoopDefaultMode);
    CFRelease(gCurrentAppObserver);
    gCurrentAppObserver = NULL;
  }

  // Create a new observer for the application
  AXError error =
      AXObserverCreate(pid, focusedWindowCallback, &gCurrentAppObserver);
  if (error != kAXErrorSuccess) {
    NSLog(@"Error creating observer: %d", error);
    return NO;
  }

  // Create a reference to the application's UI element
  gCurrentAppElement = AXUIElementCreateApplication(pid);

  // Register for focused window changed notification
  error = AXObserverAddNotification(gCurrentAppObserver, gCurrentAppElement,
                                    kAXFocusedWindowChangedNotification, NULL);
  if (error != kAXErrorSuccess) {
    NSLog(@"Error adding window focus notification: %d", error);
    CFRelease(gCurrentAppElement);
    gCurrentAppElement = NULL;
    CFRelease(gCurrentAppObserver);
    gCurrentAppObserver = NULL;
    return NO;
  }

  // Add the observer to the run loop
  CFRunLoopAddSource(CFRunLoopGetCurrent(),
                     AXObserverGetRunLoopSource(gCurrentAppObserver),
                     kCFRunLoopDefaultMode);

  // Trigger the callback once to observe the currently focused window
  focusedWindowCallback(gCurrentAppObserver, gCurrentAppElement,
                        kAXFocusedWindowChangedNotification, NULL);

  NSLog(@"Observing process %d for window focus changes", pid);
  return YES;
}

// Function to observe focused application changes and window title changes
void observeFocusedAppChanges() {
  // Initialize the window observers dictionary
  if (gWindowObservers == nil) {
    gWindowObservers = [NSMutableDictionary dictionary];
  }

  // Log the current thread information
  NSLog(@"observeFocusedAppChanges running on thread: %@ (isMainThread: %@)",
        [NSThread currentThread].name,
        [NSThread isMainThread] ? @"YES" : @"NO");

  // First observe the currently focused application
  NSRunningApplication *currentApp =
      [[NSWorkspace sharedWorkspace] frontmostApplication];
  if (currentApp) {
    NSLog(@"Starting with app: %@ (Bundle ID: %@)", currentApp.localizedName,
          currentApp.bundleIdentifier);
    BOOL success = startObservingApp(currentApp.processIdentifier);
    NSLog(@"startObservingApp result: %@", success ? @"SUCCESS" : @"FAILURE");
  }

  // Register for workspace notifications to detect app switching
  [[NSWorkspace sharedWorkspace].notificationCenter
      addObserverForName:NSWorkspaceDidActivateApplicationNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *notification) {
                NSLog(@"App switch notification received on thread: %@ "
                      @"(isMainThread: %@)",
                      [NSThread currentThread].name,
                      [NSThread isMainThread] ? @"YES" : @"NO");

                NSRunningApplication *app =
                    notification.userInfo[NSWorkspaceApplicationKey];
                NSLog(@"Focused app changed to: %@ (Bundle ID: %@)",
                      app.localizedName, app.bundleIdentifier);

                // Start observing the newly focused app
                BOOL success = startObservingApp(app.processIdentifier);
                NSLog(@"startObservingApp result: %@",
                      success ? @"SUCCESS" : @"FAILURE");
              }];

  NSLog(@"Observing for application focus and window title changes");
}

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

        // Observe application focus changes and window title changes
        observeFocusedAppChanges();

        // Run the run loop on this thread to receive notifications
        NSLog(@"Starting run loop on observer thread");
        CFRunLoopRun();

        // Clean up (this won't be reached unless the run loop is stopped)
        if (gCurrentAppObserver != NULL) {
          if (gCurrentAppElement != NULL) {
            AXObserverRemoveNotification(gCurrentAppObserver,
                                         gCurrentAppElement,
                                         kAXFocusedWindowChangedNotification);
            CFRelease(gCurrentAppElement);
          }
          CFRelease(gCurrentAppObserver);
        }

        // Clean up window observers
        for (id key in gWindowObservers) {
          AXObserverRef observer =
              (__bridge AXObserverRef)([gWindowObservers objectForKey:key]);
          CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                AXObserverGetRunLoopSource(observer),
                                kCFRunLoopDefaultMode);
        }
        [gWindowObservers removeAllObjects];
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