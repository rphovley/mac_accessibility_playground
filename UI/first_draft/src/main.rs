use std::ffi::c_void;
use std::sync::Arc;
use std::thread;

// FFI declarations for the Objective-C functions
#[link(name = "hello_window")]
extern "C" {
    fn init_hello_window() -> *mut c_void;
    fn show_hello_window(controller: *mut c_void);
    fn run_application();
    fn cleanup_hello_window(controller: *mut c_void);
}

// A wrapper to make our pointer thread-safe
struct WindowController(*mut c_void);
// This is safe because our Objective-C code handles thread safety internally
unsafe impl Send for WindowController {}
unsafe impl Sync for WindowController {}

impl Drop for WindowController {
    fn drop(&mut self) {
        unsafe {
            if !self.0.is_null() {
                cleanup_hello_window(self.0);
            }
        }
    }
}

fn main() {
    println!("Starting application on main thread...");

    unsafe {
        // Initialize the window (this creates the NSApplication instance)
        let window_controller = WindowController(init_hello_window());

        // Wrap in Arc to share between threads
        let controller = Arc::new(window_controller);
        let controller_clone = controller.clone();

        // Create a background thread to show the window
        thread::spawn(move || {
            println!("Background thread: Opening Hello World window...");
            show_hello_window(controller_clone.0);
        });

        // Run the application main loop on the main thread
        println!("Main thread: Running application main loop...");
        run_application();

        // The window controller will be cleaned up automatically when the Arc is dropped
    }
}
