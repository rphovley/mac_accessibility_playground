use libc::c_char;
use std::ffi::CStr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::{thread, time};

// FFI declarations for the C API
#[link(name = "windowobserver")]
extern "C" {
    fn start_window_observing(
        callback: extern "C" fn(*const c_char, *const c_char, *const c_char, *const c_char),
    );
    fn stop_window_observing();
    fn is_window_observing() -> bool;
}

// Callback function that will be called from Objective-C
extern "C" fn window_change_callback(
    app_name: *const c_char,
    window_title: *const c_char,
    bundle_id: *const c_char,
    url: *const c_char,
) {
    unsafe {
        // Convert C strings to Rust strings
        let app_name = CStr::from_ptr(app_name).to_string_lossy();
        let window_title = CStr::from_ptr(window_title).to_string_lossy();
        let bundle_id = CStr::from_ptr(bundle_id).to_string_lossy();

        let url_str = if url.is_null() {
            "(none)".to_string()
        } else {
            CStr::from_ptr(url).to_string_lossy().to_string()
        };

        println!("Window changed:");
        println!("  App: {}", app_name);
        println!("  Title: {}", window_title);
        println!("  Bundle ID: {}", bundle_id);
        println!("  URL: {}", url_str);
        println!("-------------------");
    }
}

fn main() {
    println!("Starting window observer from Rust...");

    // Start observing window changes
    unsafe {
        start_window_observing(window_change_callback);
    }

    println!("Press Enter to exit");

    // Wait for user to press Enter
    let mut input = String::new();
    std::io::stdin()
        .read_line(&mut input)
        .expect("Failed to read line");

    // Stop observing when done
    unsafe {
        stop_window_observing();
    }

    println!("Window observer stopped");
}
