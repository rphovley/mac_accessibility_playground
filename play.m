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

    // Create indent based on depth
    char indent[100] = "";
    for (int i = 0; i < depth; i++) {
        strcat(indent, "  ");
    }
    
    printf("\n%s=== Element at depth %d ===\n", indent, depth);
    printf("%sRole: %s\n", indent, [role UTF8String]);
    if (title) {
        printf("%sTitle: %s\n", indent, [title UTF8String]);
    }
    
    for (NSString *attribute in attributes) {
        CFTypeRef valueRef;
        AXError error = AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)attribute, &valueRef);
        
        if (error == kAXErrorSuccess) {
            id value = (__bridge_transfer id)valueRef;
            printf("%sAttribute: %s = %s\n", indent, [attribute UTF8String], [[value description] UTF8String]);
            
            // Recursively explore children
            if ([attribute isEqualToString:NSAccessibilityChildrenAttribute]) {
                NSArray *children = (NSArray *)value;
                for (id child in children) {
                    printAttributes((__bridge AXUIElementRef)child, depth + 1);
                }
            }
        } else {
            printf("%sAttribute: %s (Error getting value: %d)\n", indent, [attribute UTF8String], error);
        }
    }
    printf("%s===========================\n\n", indent);
}

int main(int argc, const char * argv[]) {
    NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"company.thebrowser.Browser"];
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
        }
    }
    return 0;
}