// BrowserController.h
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

@interface BrowserController : NSObject

- (BOOL)requestAccessibilityPermissions;
- (void)controlBrowserWithURL:(NSString *)url error:(NSError **)error;
- (void)simulateKeyPressWithKeyCode:(CGKeyCode)keyCode;

@end