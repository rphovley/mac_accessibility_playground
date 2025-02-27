#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface MonitorController : NSObject

- (void)startMonitoring;
- (BOOL)requestAccessibilityPermissions;

@end