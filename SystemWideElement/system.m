#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

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


BOOL has_accessibility_permissions(void) {
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @NO};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

BOOL request_accessibility_permissions(void) {
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

int main(int argc, const char * argv[]) {
    request_accessibility_permissions();

    NSRunningApplication *frontmostApp;
    
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    printAttributes(systemWide, 0);
    AXUIElementRef focusedApp = NULL;
    AXError systemWideResult = AXUIElementCopyAttributeValue(
        systemWide,
        kAXFocusedApplicationAttribute,
        (CFTypeRef *)&focusedApp
    );

    if (systemWideResult == kAXErrorSuccess && focusedApp) {
        pid_t pid;
        AXUIElementGetPid(focusedApp, &pid);
        frontmostApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        CFRelease(focusedApp);
    }

    CFRelease(systemWide);
    
    if (!frontmostApp) {
        NSLog(@"Failed to get frontmost application");
        return 1;
    }

    return 0;
}