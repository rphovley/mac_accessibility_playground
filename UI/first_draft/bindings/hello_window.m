#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

// Forward declaration of the WindowController class
@interface WindowController : NSObject
@property(nonatomic, strong) NSWindow *window;
@end

static WindowController *globalWindowController = nil;

@implementation WindowController

- (id)init {
  self = [super init];
  if (self) {
    // Create a window
    NSRect frame = NSMakeRect(100, 100, 400, 200);
    NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:styleMask
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];

    [self.window setTitle:@"Hello World from Rust"];
    [self.window center];

    // Create a text label
    NSTextField *label =
        [[NSTextField alloc] initWithFrame:NSMakeRect(100, 100, 200, 30)];
    [label setStringValue:@"Hello World!"];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:[NSFont systemFontOfSize:24]];
    [label setAlignment:NSTextAlignmentCenter];
    [label sizeToFit];

    // Center the label in the window
    NSRect windowFrame = [[self.window contentView] bounds];
    NSRect labelFrame = [label frame];
    labelFrame.origin.x = (windowFrame.size.width - labelFrame.size.width) / 2;
    labelFrame.origin.y =
        (windowFrame.size.height - labelFrame.size.height) / 2;
    [label setFrame:labelFrame];

    [[self.window contentView] addSubview:label];
  }
  return self;
}

- (void)showWindow {
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

@end

// Initialize the application and return a handle to the window controller
void *init_hello_window() {
  @autoreleasepool {
    // Initialize the application if needed
    if (NSApp == nil) {
      [NSApplication sharedApplication];
      [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }

    // Create the window controller
    globalWindowController = [[WindowController alloc] init];
    return (__bridge_retained void *)globalWindowController;
  }
}

// Show the window (can be called from any thread)
void show_hello_window(void *controller) {
  WindowController *windowController = (__bridge WindowController *)controller;
  dispatch_async(dispatch_get_main_queue(), ^{
    [windowController showWindow];
  });
}

// Run the application main loop
void run_application() {
  @autoreleasepool {
    [NSApp finishLaunching];
    [NSApp run];
  }
}

// Clean up resources
void cleanup_hello_window(void *controller) {
  if (controller) {
    WindowController *windowController =
        (__bridge_transfer WindowController *)controller;
    windowController = nil;
  }
}