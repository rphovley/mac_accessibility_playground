#import "browser_controller.h"


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

@interface BrowserController () {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
}

@property (nonatomic, strong) NSArray<NSString *> *blockedDomains;
@property (nonatomic, strong) NSString *redirectURL;
@property (nonatomic, assign) BOOL isEnabled;

@end

@implementation BrowserController {
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

- (void)setBlockedDomains:(NSArray<NSString *> *)domains redirectTo:(NSString *)redirectURL {
    _blockedDomains = [domains copy];
    _redirectURL = [redirectURL copy];
}

- (void)setEnabled:(BOOL)enabled {
    _isEnabled = enabled;
}

- (BOOL)shouldBlockURL:(NSString *)url {
    if (!_isEnabled) return NO;
    
    for (NSString *blockedDomain in _blockedDomains) {
        if ([url containsString:blockedDomain]) {
            return YES;
        }
    }
    return NO;
}

- (void)startMonitoring {
    // Create event tap for mouse clicks and key events
    CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown) | 
                           CGEventMaskBit(kCGEventKeyDown);
    
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
    BrowserController *controller = (__bridge BrowserController *)refcon;
    
    // Only process enter key presses and mouse clicks
    if (type == kCGEventKeyDown) {
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        if (keyCode != 36) {  // 36 is the keycode for Enter/Return
            return event;
        }
    }
    
    // Small delay to allow UI to update
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [controller checkCurrentURLAndRedirectIfNeeded];
    });
    
    return event;
}

- (void)checkCurrentURLAndRedirectIfNeeded {
    printf("Checking current URL and redirecting if needed\n");
    NSError *error = nil;
    NSString *currentURL = [self getCurrentURL:&error];
    
    if (currentURL && [self shouldBlockURL:currentURL]) {
        [self controlBrowserWithURL:self.redirectURL error:&error];
    }
}

- (NSString *)getCurrentURL:(NSError **)error {
    // Get Chrome process
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace].runningApplications
                               filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"bundleIdentifier == %@", @"com.google.Chrome"]].firstObject;
    
    if (!app) return nil;
    
    AXUIElementRef appElement = AXUIElementCreateApplication(app.processIdentifier);
    AXUIElementRef window = NULL;
    AXError axError = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute, (CFTypeRef *)&window);
    
    if (axError != kAXErrorSuccess || !window) {
        CFArrayRef windowArray = NULL;
        axError = AXUIElementCopyAttributeValues(appElement, kAXWindowsAttribute, 0, 1, &windowArray);
        
        if (axError == kAXErrorSuccess && windowArray) {
            if (CFArrayGetCount(windowArray) > 0) {
                window = (AXUIElementRef)CFRetain(CFArrayGetValueAtIndex(windowArray, 0));
            }
            CFRelease(windowArray);
        }
    }
    
    if (!window) {
        CFRelease(appElement);
        return nil;
    }
    
    AXUIElementRef urlField = [self findURLFieldInElement:window];
    CFRelease(window);
    
    NSString *currentURL = nil;
    if (urlField) {
        CFTypeRef valueRef;
        axError = AXUIElementCopyAttributeValue(urlField, kAXValueAttribute, &valueRef);
        if (axError == kAXErrorSuccess) {
            currentURL = (__bridge_transfer NSString *)valueRef;
        }
        CFRelease(urlField);
    }
    
    CFRelease(appElement);
    return currentURL;
}

- (void)dealloc {
    if (_eventTap) {
        CGEventTapEnable(_eventTap, false);
        CFRelease(_eventTap);
    }
    if (_runLoopSource) {
        CFRelease(_runLoopSource);
    }
    if (_systemWideElement) {
        CFRelease(_systemWideElement);
    }
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

- (BOOL)checkDomain:(NSString *)str {
    NSString *pattern = @"^(?:https?:\\/\\/)?(?:www\\.)?[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*\\.[a-zA-Z]{2,}(?:\\/[^\\s]*)?(?:\\?[^\\s]*)?$";
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:&error];
    if (error) {
        return NO;
    }
    
    NSRange range = NSMakeRange(0, [str length]);
    NSArray *matches = [regex matchesInString:str options:0 range:range];
    
    return matches.count > 0;
}

- (AXUIElementRef)findURLFieldInElement:(AXUIElementRef)element {
    if (!element) return NULL;
    
    // Check if current element is a static text with URL value
    CFStringRef roleRef;
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&roleRef);
    NSString *role = (__bridge_transfer NSString *)roleRef;
    
    if ([role isEqualToString:NSAccessibilityStaticTextRole] || [role isEqualToString:NSAccessibilityTextFieldRole]) {
        CFTypeRef valueRef;
        AXError error = AXUIElementCopyAttributeValue(element, kAXValueAttribute, &valueRef);
        if (error == kAXErrorSuccess) {
            NSString *value = (__bridge_transfer NSString *)valueRef;
            if ([self checkDomain:value]) {
                CFRetain(element);  // Retain the element before returning it
                return element;
            }
        }
    }
    
    // Check children recursively
    CFArrayRef childrenRef;
    AXError childrenError = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, (CFTypeRef *)&childrenRef);
    
    if (childrenError == kAXErrorSuccess) {
        NSArray *children = (__bridge_transfer NSArray *)childrenRef;
        for (id child in children) {
            AXUIElementRef urlElement = [self findURLFieldInElement:(__bridge AXUIElementRef)child];
            if (urlElement != NULL) {
                return urlElement;
            }
        }
    }
    
    return NULL;
}

- (void)controlBrowserWithURL:(NSString *)url error:(NSError **)error {
    // Get Safari process
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace].runningApplications
                               filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"bundleIdentifier == %@", @"com.google.Chrome"]].firstObject;
    
    if (!app) {
        if (error) {
            *error = [NSError errorWithDomain:@"BrowserNotFound"
                                       code:1
                                   userInfo:@{NSLocalizedDescriptionKey: @"Safari browser not found"}];
        }
        return;
    }
    
    // Activate the Chrome application first
    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    [NSThread sleepForTimeInterval:0.2]; // Give it a moment to activate
    
    // Create AXUIElement for the application
    AXUIElementRef appElement = AXUIElementCreateApplication(app.processIdentifier);
    
    // Find the window
    AXUIElementRef window = NULL;
    AXError axError = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute, (CFTypeRef *)&window);
    
    if (axError != kAXErrorSuccess || !window) {
        // Try to get the first window
        CFArrayRef windowArray = NULL;
        axError = AXUIElementCopyAttributeValues(appElement, kAXWindowsAttribute, 0, 1, &windowArray);
        
        if (axError == kAXErrorSuccess && windowArray) {
            if (CFArrayGetCount(windowArray) > 0) {
                window = (AXUIElementRef)CFRetain(CFArrayGetValueAtIndex(windowArray, 0));
            }
            CFRelease(windowArray);
        }
    }
    
    if (!window) {
        if (error) {
            *error = [NSError errorWithDomain:@"AXError"
                                       code:axError
                                   userInfo:@{NSLocalizedDescriptionKey: @"Could not find browser window"}];
        }
        CFRelease(appElement);
        return;
    }
    
    // Find the URL field
    AXUIElementRef urlField = [self findURLFieldInElement:window];
    CFRelease(window);
    
    printf("URL FIELD: %s\n", [url UTF8String]);
    NSLog(@"URL FIELD: %@", urlField);
    printAttributes(urlField, 0);
    
    if (urlField) {
        // Focus the URL field
        AXUIElementSetAttributeValue(urlField, kAXFocusedAttribute, kCFBooleanTrue);
        
        // Set the URL
        axError = AXUIElementSetAttributeValue(urlField, kAXValueAttribute, (__bridge CFTypeRef)url);
        
        if (axError == kAXErrorSuccess) {
            // Small delay to ensure the value is set
            [NSThread sleepForTimeInterval:0.1];
            // Simulate Command+L to focus address bar, then Return
            // [self simulateKeyPressWithKeyCode:37 flags:kCGEventFlagMaskCommand]; // Command+L
            // [NSThread sleepForTimeInterval:0.1];
            [self simulateKeyPressWithKeyCode:36 flags:0]; // Return
        } else {
            if (error) {
                *error = [NSError errorWithDomain:@"AXError"
                                           code:axError
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to set URL"}];
            }
        }
        
        CFRelease(urlField);
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"AXError"
                                       code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Could not find URL field"}];
        }
    }
    
    CFRelease(appElement);
}

- (void)simulateKeyPressWithKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    
    // Create key down event
    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventSetFlags(keyDown, flags);
    CGEventPost(kCGHIDEventTap, keyDown);
    CFRelease(keyDown);
    
    // Small delay between down and up
    [NSThread sleepForTimeInterval:0.05];
    
    // Create key up event
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, keyCode, false);
    CGEventSetFlags(keyUp, flags);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyUp);
    
    CFRelease(source);
}

@end

// Example usage
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BrowserController *controller = [[BrowserController alloc] init];
        
        if ([controller requestAccessibilityPermissions]) {
            // Set up blocked domains and redirect URL
            [controller setBlockedDomains:@[@"facebook.com", @"twitter.com", @"instagram.com", @"x.com"]
                              redirectTo:@"https://codeclimbers.io"];
            
            // Enable the blocker
            [controller setEnabled:YES];
            
            // Start monitoring
            [controller startMonitoring];
            
            // Keep the program running
            [[NSRunLoop currentRunLoop] run];
        } else {
            NSLog(@"Accessibility permissions not granted");
        }
    }
    return 0;
}