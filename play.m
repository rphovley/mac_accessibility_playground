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

BOOL checkDomain(NSString *str) {
    NSString *pattern = @"^(?:https?:\\/\\/)?(?:www\\.)?[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*\\.[a-zA-Z]{2,}(?:\\/[^\\s]*)?(?:\\?[^\\s]*)?$";
    printf("PATTERN: %s\n", [pattern UTF8String]);
    printf("STR: %s\n", [str UTF8String]);
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

AXUIElementRef findUrlElement(AXUIElementRef element) {
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
            // Simple URL pattern matching (you might want to make this more robust)
            if (checkDomain(value)) {
                printf("FOUND\n");
                printf("VALUE: %s\n", [value UTF8String]);
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
            AXUIElementRef urlElement = findUrlElement((__bridge AXUIElementRef)child);
            if (urlElement != NULL) {
                return urlElement;
            }
        }
    }
    
    return NULL;
}

int main(int argc, const char * argv[]) {
    NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.google.Chrome"];
    // NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.Safari"];
    // NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"company.thebrowser.Browser"];
    NSLog(@"Running apps: %@", runningApps);
    for (NSRunningApplication *app in runningApps) {
        printf("Exploring app: %s\n", [app.localizedName UTF8String]);
        AXUIElementRef appRef = AXUIElementCreateApplication(app.processIdentifier);
        
        CFArrayRef windowsRef;
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, (CFTypeRef *)&windowsRef);
        NSArray *windows = (__bridge_transfer NSArray *)windowsRef;
        
        for (id window in windows) {
            AXUIElementRef windowRef = (__bridge AXUIElementRef)window;
            printAttributes(windowRef, 0);
            AXUIElementRef urlElement = findUrlElement(windowRef);
            
            if (urlElement) {
                CFTypeRef valueRef;
                printAttributes(urlElement, 0);
                AXUIElementCopyAttributeValue(urlElement, kAXValueAttribute, &valueRef);
                NSString *url = (__bridge_transfer NSString *)valueRef;
                printf("Found URL: %s\n", [url UTF8String]);
                
                // Now you can use this element for navigation
                // setTextValue(urlElement, @"https://new-url.com");
            }
        }
    }
    return 0;
}