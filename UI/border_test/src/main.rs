use std::os::raw::{c_double, c_int};

#[link(name = "border_test", kind = "static")]
extern "C" {
    fn create_border(
        red: c_double,
        green: c_double,
        blue: c_double,
        width: c_double,
        opacity: c_double,
    ) -> c_int;

    fn remove_border() -> c_int;
    fn start_monitoring() -> c_int;
    fn run_loop() -> c_int;
}

fn main() {
    // Your main application logic here
    println!("Starting main application...");

    unsafe {
        start_monitoring();
        run_loop();
    }
    // Keep the program running to maintain the border
    println!("Press Ctrl+C to exit");
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
