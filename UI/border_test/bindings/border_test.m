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

      dispatch_async(
          dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSApp activateIgnoringOtherApps:YES];
            [NSApp run];
          });
      run_loop();

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

// Function to create a border when Enter key is pressed
void setup_key_event_monitor() {
  NSLog(@"Setting up key event monitor for Enter key");

  eventMonitor = [NSEvent
      addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                    handler:^(NSEvent *event) {
                                      if ([event keyCode] ==
                                          36) { // 36 is the key code for
                                                // Enter/Return
                                        NSLog(@"Enter key pressed, creating "
                                              @"border");
                                        // Create a blue border when Enter is
                                        // pressed
                                        create_border(0.0, 0.0, 1.0, 8.0, 0.7);
                                      }
                                    }];
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSLog(@"Starting border test...");

    // Set up the application
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // Set up the key event monitor instead of immediately creating a border
    setup_key_event_monitor();
    create_border(0.0, 0.0, 1.0, 8.0, 0.7);

    NSLog(@"Event monitor set up. Press Enter to create a border. Press Ctrl+C "
          @"to exit.");
    run_loop();
  }
  return 0;
}
