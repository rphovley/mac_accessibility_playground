use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:warning=Build script starting...");

    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    println!("cargo:info=Target OS: {}", target_os);

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    println!("cargo:info=Manifest dir: {}", manifest_dir.display());

    if target_os == "macos" {
        println!("cargo:info=Building for macOS...");

        // Define all source files
        let source_files = [manifest_dir.join("bindings").join("hello_window.m")];

        // Define all header files (for dependency tracking)
        let header_files = [];

        let out_dir = std::env::var("OUT_DIR").unwrap();
        let out_path = PathBuf::from(out_dir);
        let include_dir = source_files[0].parent().unwrap();

        println!("cargo:info=Source files: {:?}", source_files);
        println!("cargo:info=Output directory: {}", out_path.display());

        // Build the Objective-C code using clang
        println!("cargo:info=Compiling Objective-C code...");
        let status = std::process::Command::new("clang")
            .args(&[
                "-fobjc-arc",
                "-fmodules",
                "-framework",
                "Cocoa",
                "-dynamiclib",
            ])
            // Add all source files as separate arguments
            .args(source_files.iter().map(|p| p.to_str().unwrap()))
            .args(&[
                "-I",
                include_dir.to_str().unwrap(),
                "-o",
                out_path.join("libhello_window.dylib").to_str().unwrap(),
            ])
            .status()
            .expect("Failed to execute clang command");

        if !status.success() {
            panic!("Objective-C compilation failed");
        }

        println!("cargo:info=Setting up library paths...");
        println!("cargo:rustc-link-search=native={}", out_path.display());
        println!("cargo:rustc-link-lib=hello_window");

        // Link against required frameworks
        println!("cargo:rustc-link-lib=framework=Cocoa");
        println!("cargo:rustc-link-lib=framework=Foundation");

        // Tell Cargo to rerun if any of our source or header files change
        for file in source_files.iter().chain(header_files.iter()) {
            println!("cargo:rerun-if-changed={}", file.display());
        }
    }
}
