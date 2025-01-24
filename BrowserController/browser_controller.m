#import "BrowserController.h"

@implementation BrowserController {
    AXUIElementRef _systemWideElement;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _systemWideElement = AXUIElementCreateSystemWide();
    }
    return self;
}

- (void)dealloc {
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

- (void)controlBrowserWithURL:(NSString *)url error:(NSError **)error {
    // Get Safari process (you can modify for different browsers)
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace].runningApplications
                               filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"bundleIdentifier == %@", @"com.apple.Safari"]].firstObject;
    
    if (!app) {
        if (error) {
            *error = [NSError errorWithDomain:@"BrowserNotFound"
                                       code:1
                                   userInfo:@{NSLocalizedDescriptionKey: @"Safari browser not found"}];
        }
        return;
    }
    
    // Create AXUIElement for the application
    AXUIElementRef appElement = AXUIElementCreateApplication(app.processIdentifier);
    
    // Get the URL field
    AXUIElementRef urlField;
    AXError axError = AXUIElementCopyAttributeValue(appElement,
                                                   kAXFocusedUIElementAttribute,
                                                   (CFTypeRef *)&urlField);
    
    if (axError == kAXErrorSuccess) {
        // Set the URL
        axError = AXUIElementSetAttributeValue(urlField,
                                             kAXValueAttribute,
                                             (__bridge CFTypeRef)url);
        
        if (axError == kAXErrorSuccess) {
            // Simulate Return key press
            [self simulateKeyPressWithKeyCode:36]; // 36 is the key code for Return
        }
        
        CFRelease(urlField);
    }
    
    if (axError != kAXErrorSuccess && error) {
        *error = [NSError errorWithDomain:@"AXError"
                                   code:axError
                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to interact with browser"}];
    }
    
    CFRelease(appElement);
}

- (void)simulateKeyPressWithKeyCode:(CGKeyCode)keyCode {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    
    // Create key down event
    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventPost(kCGHIDEventTap, keyDown);
    CFRelease(keyDown);
    
    // Create key up event
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, keyCode, false);
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
            NSError *error = nil;
            [controller controlBrowserWithURL:@"https://www.apple.com" error:&error];
            
            if (error) {
                NSLog(@"Error controlling browser: %@", error);
            }
        } else {
            NSLog(@"Accessibility permissions not granted");
        }
    }
    return 0;
}