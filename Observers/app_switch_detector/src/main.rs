use std::ffi::{c_void, CStr};
use std::os::raw::c_char;

// FFI declarations for the Objective-C functions
#[link(name = "app_switch_detector")]
extern "C" {
    fn init_app_switch_detector(callback: extern "C" fn(*const c_char)) -> *mut c_void;
    fn process_events();
    fn cleanup_app_switch_detector(observer: *mut c_void);
}

// Callback function that will be called from Objective-C
extern "C" fn app_switched_callback(app_name: *const c_char) {
    unsafe {
        if !app_name.is_null() {
            let name = CStr::from_ptr(app_name).to_string_lossy();
            println!("Application switched to: {}", name);
            // You can add your Rust-specific logic here
        }
    }
}

fn main() {
    println!("Starting application switch detector from Rust...");

    // Initialize the app switch detector
    std::thread::spawn(|| unsafe {
        let observer = unsafe { init_app_switch_detector(app_switched_callback) };

        // Main event loop
        // Process events for a short time
        unsafe {
            process_events();
        }

        // Add any other Rust logic here
        // You might want to add a way to break out of this loop

        // Clean up (this won't be reached in the current implementation)
        unsafe {
            cleanup_app_switch_detector(observer);
        }
    });
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
