#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

// Forward declaration of the AppSwitchObserver class
@interface AppSwitchObserver : NSObject
// Use assign instead of copy for function pointers
@property(nonatomic, assign) void (*callback)(const char *);
@end

static AppSwitchObserver *globalObserver = nil;

@implementation AppSwitchObserver

- (id)initWithCallback:(void (*)(const char *))callback {
  self = [super init];
  if (self) {
    self.callback = callback;

    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver:self
           selector:@selector(activeApplicationChanged:)
               name:NSWorkspaceDidActivateApplicationNotification
             object:nil];

    NSRunningApplication *currentApp =
        [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (currentApp) {
      NSLog(@"Current active application: %@", [currentApp localizedName]);
      if (self.callback) {
        self.callback([[currentApp localizedName] UTF8String]);
      }
    }
  }
  return self;
}

- (void)dealloc {
  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)activeApplicationChanged:(NSNotification *)notification {
  NSRunningApplication *app =
      [notification.userInfo objectForKey:NSWorkspaceApplicationKey];
  if (app) {
    NSLog(@"Application switched to: %@", [app localizedName]);
    if (self.callback) {
      self.callback([[app localizedName] UTF8String]);
    }
  }
}

@end

// Initialize the app switch detector with a callback function
void *init_app_switch_detector(void (*callback)(const char *)) {
  @autoreleasepool {
    globalObserver = [[AppSwitchObserver alloc] initWithCallback:callback];
  }
}

void process_events() {
  @autoreleasepool {
    NSLog(@"Processing events");

    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];

    // Add a port to keep the run loop alive (needed for background threads)
    NSPort *port = [NSPort port];
    [currentRunLoop addPort:port forMode:NSDefaultRunLoopMode];

    [currentRunLoop run];

    NSLog(@"Finished processing events");
  }
}

// Clean up resources
void cleanup_app_switch_detector() {
  @autoreleasepool {
    globalObserver = nil;
  }
}

// Test callback function for standalone testing
void test_callback(const char *app_name) {
  printf("App switched to: %s\n", app_name);
}

// Main function for standalone testing
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSLog(@"Starting app switch detector test...");

    // Initialize the detector with our test callback
    init_app_switch_detector(test_callback);

    // Run the event loop for a while
    NSLog(@"Running event loop. Switch between applications to see output.");
    NSLog(@"Press Ctrl+C to exit.");

    process_events();

    // This won't be reached due to the infinite loop above
    cleanup_app_switch_detector();
  }
  return 0;
}
