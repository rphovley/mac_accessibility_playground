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
        let source_files = [manifest_dir.join("bindings").join("observers.m")];

        // Define all header files (for dependency tracking)
        let header_files = [manifest_dir.join("bindings").join("window_observer.h")];

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
                out_path.join("libwindowobserver.dylib").to_str().unwrap(),
            ])
            .status()
            .expect("Failed to execute clang command");

        if !status.success() {
            panic!("Objective-C compilation failed");
        }

        println!("cargo:info=Setting up library paths...");
        println!("cargo:rustc-link-search=native={}", out_path.display());
        println!("cargo:rustc-link-lib=windowobserver");

        // Link against required frameworks
        println!("cargo:rustc-link-lib=framework=Cocoa");
        println!("cargo:rustc-link-lib=framework=Foundation");

        // Tell Cargo to rerun if any of our source or header files change
        for file in source_files.iter().chain(header_files.iter()) {
            println!("cargo:rerun-if-changed={}", file.display());
        }
    } else if target_os == "windows" {
        println!("cargo:info=Building for Windows...");

        let source_path = manifest_dir
            .join("bindings")
            .join("windows_monitor")
            .join("windows_monitor")
            .join("monitor.c");
        let output_dir = manifest_dir
            .join("bindings")
            .join("windows_monitor")
            .join("windows_monitor")
            .join("release");

        println!("cargo:info=Source path: {}", source_path.display());
        println!("cargo:info=Output directory: {}", output_dir.display());

        std::fs::create_dir_all(&output_dir).unwrap();

        // Compile the C code
        println!("cargo:info=Compiling C code...");
        cc::Build::new()
            .file(&source_path)
            .static_flag(false) // Not a static library
            .out_dir(&output_dir) // Specify where to put the output
            .compile("WindowsMonitor");

        println!("cargo:info=Setting up library paths...");
        println!("cargo:rustc-link-search=native={}", output_dir.display());
        println!("cargo:rustc-link-lib=WindowsMonitor");

        println!("cargo:rustc-link-lib=user32");

        // Tell Cargo to rerun if our source changes
        println!("cargo:rerun-if-changed={}", source_path.display());
        println!("cargo:warning=Build script completed successfully");
    }
}
