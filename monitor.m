#include <ApplicationServices/ApplicationServices.h>
#include <Cocoa/Cocoa.h>

typedef void (*KeyboardEventCallback)(int32_t keyCode);

@interface MonitorHolder : NSObject
@property (nonatomic, strong) NSArray<id> *monitors;
@property (nonatomic, assign) KeyboardEventCallback keyboardCallback;
@end

@implementation MonitorHolder
@end

static MonitorHolder *monitorHolder = nil;

void start_keyboard_monitoring(KeyboardEventCallback callback) {
    if (!monitorHolder) {
        monitorHolder = [[MonitorHolder alloc] init];
    }
    
    id keyboardMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                               handler:^(NSEvent *event) {
        callback((int32_t)event.keyCode);
    }];
    
    if (keyboardMonitor) {
        if (!monitorHolder.monitors) {
            monitorHolder.monitors = @[];
        }
        monitorHolder.monitors = [monitorHolder.monitors arrayByAddingObject:keyboardMonitor];
    }
}

void keybaord_event_callback(int32_t keycode) {
    printf("KEYBOARD EVENT: %d\n", keycode);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        printf("STARTING KEYBOARD MONITORING\n");
        // TODO: Add a loop to keep the program running until it's terminated

        start_keyboard_monitoring(keybaord_event_callback);
        while (true) {
            NSDate *until = [NSDate dateWithTimeIntervalSinceNow:0.1];  // 100ms collection window
            NSEvent *event;
            while ((event = [[NSApplication sharedApplication] 
                    nextEventMatchingMask:NSEventMaskAny
                    untilDate:until  // Changed from nil to until
                    inMode:NSDefaultRunLoopMode
                    dequeue:YES])) {
                [[NSApplication sharedApplication] sendEvent:event];
            }
            sleep(10);
        }
    }
    return 0;
}