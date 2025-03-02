#ifndef WINDOW_OBSERVER_H
#define WINDOW_OBSERVER_H

#ifdef __cplusplus
extern "C" {
#endif

// Callback type for window changes
typedef void (*WindowChangeCallback)(const char *app_name,
                                     const char *window_title,
                                     const char *bundle_id, const char *url);

// Start observing window changes with the given callback
void start_window_observing(WindowChangeCallback callback);

// Stop observing window changes
void stop_window_observing(void);

// Check if currently observing
bool is_window_observing(void);

#ifdef __cplusplus
}
#endif

#endif // WINDOW_OBSERVER_H