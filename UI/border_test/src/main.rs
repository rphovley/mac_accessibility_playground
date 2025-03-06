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
}

fn main() {
    // Your main application logic here
    println!("Starting main application...");

    // Create a yellow border
    unsafe {
        let result = create_border(1.0, 1.0, 0.0, 20.0, 0.3);
        println!("Yellow border created with result: {}", result);
    }

    // Simulate some application work
    std::thread::sleep(std::time::Duration::from_secs(2));

    // Change to a cyan border
    unsafe {
        let result = create_border(0.0, 1.0, 1.0, 20.0, 0.3);
        println!("Cyan border created with result: {}", result);
    }

    std::thread::sleep(std::time::Duration::from_secs(2));

    // Remove the border
    unsafe {
        let result = remove_border();
        println!("Border removed with result: {}", result);
    }

    std::thread::sleep(std::time::Duration::from_secs(2));

    // Create a green border
    unsafe {
        let result = create_border(0.0, 1.0, 0.0, 20.0, 0.3);
        println!("Green border created with result: {}", result);
    }

    // Keep the program running to maintain the border
    println!("Press Ctrl+C to exit");
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
