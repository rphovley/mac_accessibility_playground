#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@interface BorderWindow : NSWindow
@property(nonatomic, strong) NSColor *borderColor;
@property(nonatomic, assign) CGFloat borderWidth;
@property(nonatomic, assign) CGFloat borderOpacity;
@end

@implementation BorderWindow

- (instancetype)initWithContentRect:(NSRect)contentRect
                          styleMask:(NSWindowStyleMask)style
                            backing:(NSBackingStoreType)backingStoreType
                              defer:(BOOL)flag {
  self = [super initWithContentRect:contentRect
                          styleMask:NSWindowStyleMaskBorderless
                            backing:backingStoreType
                              defer:flag];
  if (self) {
    [self setBackgroundColor:[NSColor clearColor]];
    [self setOpaque:NO];
    [self setLevel:NSStatusWindowLevel];
    [self setIgnoresMouseEvents:YES];

    // Default values
    _borderColor = [NSColor redColor];
    _borderWidth = 5.0;
    _borderOpacity = 1.0;
  }
  return self;
}

- (void)drawBorder {
  [self setAlphaValue:self.borderOpacity];
  [self.contentView setWantsLayer:YES];
  self.contentView.layer.borderWidth = self.borderWidth;
  self.contentView.layer.borderColor = self.borderColor.CGColor;
}

@end

// Global variable to store the event monitor
id eventMonitor = nil;
// Global variable to track if border is displayed
BOOL borderDisplayed = NO;
// Global variable to store the current border window
BorderWindow *currentBorderWindow = nil;

void run_loop() { [[NSRunLoop currentRunLoop] run]; }

int create_border(double red, double green, double blue, double width,
                  double opacity) {
  @autoreleasepool {
    @try {
      NSLog(@"Creating border with color RGB(%.2f, %.2f, %.2f), width: %.2f, "
            @"opacity: %.2f",
            red, green, blue, width, opacity);

      [NSApplication sharedApplication];
      [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

      NSScreen *mainScreen = [NSScreen mainScreen];
      NSRect screenFrame = [mainScreen frame];

      BorderWindow *borderWindow =
          [[BorderWindow alloc] initWithContentRect:screenFrame
                                          styleMask:NSWindowStyleMaskBorderless
                                            backing:NSBackingStoreBuffered
                                              defer:NO];

      borderWindow.borderColor = [NSColor colorWithRed:red
                                                 green:green
                                                  blue:blue
                                                 alpha:1.0];
      borderWindow.borderWidth = width;
      borderWindow.borderOpacity = opacity;

      [borderWindow drawBorder];
      [borderWindow makeKeyAndOrderFront:nil];

      // Store reference to the current border window
      currentBorderWindow = borderWindow;
      borderDisplayed = YES;

      dispatch_async(
          dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSApp activateIgnoringOtherApps:YES];
            [NSApp run];
          });

      return 0; // Success
    } @catch (NSException *exception) {
      NSLog(@"Exception caught: %@", exception);
      NSLog(@"Reason: %@", [exception reason]);
      NSLog(@"Stack trace: %@", [exception callStackSymbols]);
      return 1; // Error
    } @finally {
      NSLog(@"Border creation attempt completed");
    }
  }
}

int remove_border() {
  @autoreleasepool {
    @try {
      NSLog(@"Removing border");

      if (currentBorderWindow != nil) {
        [currentBorderWindow close];
        currentBorderWindow = nil;
        borderDisplayed = NO;
        NSLog(@"Border removed successfully");
      } else {
        NSLog(@"No border to remove");
      }

      return 0; // Success
    } @catch (NSException *exception) {
      NSLog(@"Exception caught while removing border: %@", exception);
      NSLog(@"Reason: %@", [exception reason]);
      NSLog(@"Stack trace: %@", [exception callStackSymbols]);
      return 1; // Error
    } @finally {
      NSLog(@"Border removal attempt completed");
    }
  }
}

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type,
                         CGEventRef event, void *refcon) {
  switch (type) {
  case kCGEventKeyDown: {
    // Get the key code
    int64_t keyCode =
        CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);

    // if enter is pressed, toggle border
    if (keyCode == 36) {
      NSLog(@"Enter key pressed");
      if (borderDisplayed) {
        NSLog(@"Border is displayed, removing it");
        remove_border();
      } else {
        NSLog(@"Border is not displayed, creating it");
        create_border(1.0, 1.0, 0.0, 8.0, 0.7); // Yellow border
      }
    }

    NSLog(@"Key pressed: %lld", keyCode);
    break;
  }
  default:
    break;
  }

  return event;
}

void start_monitoring() {
  // Create event tap for mouse clicks, movements, and key events
  CGEventMask eventMask =
      CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);

  CFMachPortRef _eventTap = CGEventTapCreate(
      kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
      eventMask, eventCallback, NULL);
  if (!_eventTap) {
    NSLog(@"Failed to create event tap");

    return;
  }
  CFRunLoopSourceRef _runLoopSource =
      CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource,
                     kCFRunLoopCommonModes);
  CGEventTapEnable(_eventTap, true);

  // start_run_loop();
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSLog(@"Starting border test...");

    // Initialize global variables
    borderDisplayed = NO;
    currentBorderWindow = nil;

    // Set up the application
    // [NSApplication sharedApplication];
    // [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // Set up the key event monitor before running the loop
    start_monitoring();

    // Create initial border
    create_border(1.0, 0.0, 0.0, 8.0, 0.7); // Red border initially

    NSLog(
        @"Event monitor set up. Press Enter to toggle the border. Press Ctrl+C "
        @"to exit.");

    // Run the main event loop on the main thread
    [[NSRunLoop mainRunLoop] run];
  }
  return 0;
}
