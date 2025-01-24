#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface BrowserController : NSObject

- (void)setBlockedDomains:(NSArray<NSString *> *)domains redirectTo:(NSString *)redirectURL;
- (void)setEnabled:(BOOL)enabled;
- (void)startMonitoring;
- (BOOL)requestAccessibilityPermissions;
- (void)controlBrowserWithURL:(NSString *)url error:(NSError **)error;
- (void)simulateKeyPressWithKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags;

@end