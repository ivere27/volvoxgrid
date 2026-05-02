fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/windows_mingw_compat.c");

    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let target_env = std::env::var("CARGO_CFG_TARGET_ENV").unwrap_or_default();
    if target_os == "windows" && target_env == "gnu" {
        cc::Build::new()
            .file("src/windows_mingw_compat.c")
            .flag_if_supported("-Wno-unused-parameter")
            .compile("volvoxgrid_windows_mingw_compat");
    }
}
