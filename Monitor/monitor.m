#import "monitor.h"
void printAttributes(AXUIElementRef element, int depth) {
    if (!element) return;
    
    CFArrayRef attributeNames;
    AXUIElementCopyAttributeNames(element, &attributeNames);
    NSArray *attributes = (__bridge_transfer NSArray *)attributeNames;

    CFStringRef titleRef;
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute, (CFTypeRef *)&titleRef);
    NSString *title = (__bridge_transfer NSString *)titleRef;
    
    CFStringRef roleRef;
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&roleRef);
    NSString *role = (__bridge_transfer NSString *)roleRef;

    // Create indent based on depth with colors
    char indent[100] = "";
    // ANSI foreground color codes from 31-36 (red, green, cyan, blue, magenta, yellow)
    int colorCode = 31 + (depth % 6);
    for (int i = 0; i < depth; i++) {
        strcat(indent, "  "); // Just add spaces without color
    }
    
    // Add color code at the start of the line, but after the indent
    char colorStart[20];
    sprintf(colorStart, "\033[%dm", colorCode);
    
    // Reset color code at the end of indent
    char resetColor[] = "\033[0m";
    
    printf("\n%s%s=== Element at depth %d ===%s\n", indent, colorStart, depth, resetColor);
    printf("%s%sRole: %s%s\n", indent, colorStart, [role UTF8String], resetColor);
    if (title) {
        printf("%s%sTitle: %s%s\n", indent, colorStart, [title UTF8String], resetColor);
    }
    
    for (NSString *attribute in attributes) {
        CFTypeRef valueRef;
        AXError error = AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)attribute, &valueRef);
        
        if (error == kAXErrorSuccess) {
            id value = (__bridge_transfer id)valueRef;
            printf("%s%sAttribute: %s = %s%s\n", indent, colorStart, [attribute UTF8String], [[value description] UTF8String], resetColor);
            
            // Recursively explore children
            if ([attribute isEqualToString:NSAccessibilityChildrenAttribute]) {
                NSArray *children = (NSArray *)value;
                for (id child in children) {
                    printAttributes((__bridge AXUIElementRef)child, depth + 1);
                }
            }
        } else {
            printf("%s%sAttribute: %s (Error getting value: %d)%s\n", indent, colorStart, [attribute UTF8String], error, resetColor);
        }
    }
    printf("%s%s===========================%s\n\n", indent, colorStart, resetColor);
}

@interface MonitorController () {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
}

@property (nonatomic, strong) NSArray<NSString *> *blockedDomains;
@property (nonatomic, strong) NSString *redirectURL;
@property (nonatomic, assign) BOOL isEnabled;

@end

@implementation MonitorController {
    AXUIElementRef _systemWideElement;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _systemWideElement = AXUIElementCreateSystemWide();
        _blockedDomains = @[]; // Initialize with empty array
        _redirectURL = @"https://codeclimbers.io"; // Default redirect
        _isEnabled = NO; // Disabled by default
    }
    return self;
}


- (BOOL)requestAccessibilityPermissions {
    BOOL trusted = AXIsProcessTrusted();
    
    if (!trusted) {
        NSDictionary *options = @{
            (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES
        };
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    }
    
    return trusted;
}

- (void)startMonitoring {
    // Create event tap for mouse clicks and key events
    CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown) | 
                           CGEventMaskBit(kCGEventLeftMouseUp) |
                           CGEventMaskBit(kCGEventRightMouseDown) |
                           CGEventMaskBit(kCGEventRightMouseUp) |
                           CGEventMaskBit(kCGEventMouseMoved) |
                           CGEventMaskBit(kCGEventScrollWheel) |
                           CGEventMaskBit(kCGEventKeyDown) |
                           CGEventMaskBit(kCGEventKeyUp);
    
    _eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                eventMask,
                                eventCallback,
                                (__bridge void * _Nullable)(self));
    
    if (!_eventTap) {
        NSLog(@"Failed to create event tap");
        return;
    }
    
    _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_eventTap, true);
}

static CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MonitorController *controller = (__bridge MonitorController *)refcon;
    printf("eventCallback on thread: %s\n", [[[NSThread currentThread] description] UTF8String]);
    // Only process enter key presses and mouse clicks
    if (type == kCGEventKeyDown) {
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        if (keyCode != 36) {  // 36 is the keycode for Enter/Return
            return event;
        }
    }
    
    // Small delay to allow UI to update
    // dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //     [controller checkCurrentURLAndRedirectIfNeeded];
    // });
    
    return event;
}


@end

// Example usage
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        MonitorController *controller = [[MonitorController alloc] init];
        
        if ([controller requestAccessibilityPermissions]) {
            // Create a separate dispatch queue for monitoring
            [controller startMonitoring];

            dispatch_queue_t monitorQueue = dispatch_queue_create("com.monitor.queue", DISPATCH_QUEUE_SERIAL);
            dispatch_async(monitorQueue, ^{
                // Start monitoring on the new thread
                [controller startMonitoring];
                
                // Run the loop on this thread
                [[NSRunLoop currentRunLoop] run];
            });
            
            // Keep the main thread running
            [[NSRunLoop mainRunLoop] run];
        } else {
            NSLog(@"Accessibility permissions not granted");
        }
    }
    return 0;
}