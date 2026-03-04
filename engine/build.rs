use std::process::Command;

fn command_stdout(cmd: &mut Command) -> Option<String> {
    let output = cmd.output().ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8(output.stdout).ok()?;
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return None;
    }
    Some(trimmed.to_string())
}

fn resolve_env_or(var: &str, fallback: impl FnOnce() -> Option<String>) -> String {
    if let Ok(value) = std::env::var(var) {
        let trimmed = value.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    fallback().unwrap_or_else(|| "unknown".to_string())
}

fn emit_git_rerun_hints() {
    let git_head = "../.git/HEAD";
    println!("cargo:rerun-if-changed={git_head}");
    if let Ok(head) = std::fs::read_to_string(git_head) {
        if let Some(reference) = head.trim().strip_prefix("ref: ") {
            println!("cargo:rerun-if-changed=../.git/{reference}");
        }
    }
}

fn workspace_version_file() -> Option<std::path::PathBuf> {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").ok()?;
    Some(std::path::Path::new(&manifest_dir).join("../VERSION"))
}

fn version_from_version_file() -> Option<String> {
    let path = workspace_version_file()?;
    println!("cargo:rerun-if-changed={}", path.display());
    let text = std::fs::read_to_string(path).ok()?;
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return None;
    }
    Some(trimmed.to_string())
}

fn emit_build_metadata() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../proto/volvoxgrid.proto");
    println!("cargo:rerun-if-env-changed=VOLVOXGRID_VERSION");
    println!("cargo:rerun-if-env-changed=VOLVOXGRID_GIT_COMMIT");
    println!("cargo:rerun-if-env-changed=VOLVOXGRID_BUILD_DATE");
    emit_git_rerun_hints();

    let version = resolve_env_or("VOLVOXGRID_VERSION", || {
        version_from_version_file().or_else(|| std::env::var("CARGO_PKG_VERSION").ok())
    });
    let git_commit = resolve_env_or("VOLVOXGRID_GIT_COMMIT", || {
        command_stdout(Command::new("git").args(["rev-parse", "--short=12", "HEAD"]))
    });
    let build_date = resolve_env_or("VOLVOXGRID_BUILD_DATE", || {
        command_stdout(Command::new("date").args(["-u", "+%Y-%m-%dT%H:%M:%SZ"]))
    });

    println!("cargo:rustc-env=VOLVOXGRID_VERSION={version}");
    println!("cargo:rustc-env=VOLVOXGRID_GIT_COMMIT={git_commit}");
    println!("cargo:rustc-env=VOLVOXGRID_BUILD_DATE={build_date}");
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    emit_build_metadata();

    let includes: &[&str] = &["../proto"];
    let protos: &[&str] = &["../proto/volvoxgrid.proto"];
    #[cfg(feature = "grpc")]
    {
        tonic_build::configure()
            .build_server(false)
            .build_client(false)
            .protoc_arg("--experimental_allow_proto3_optional")
            .compile(protos, includes)?;
    }
    #[cfg(not(feature = "grpc"))]
    {
        let mut config = prost_build::Config::new();
        config.protoc_arg("--experimental_allow_proto3_optional");
        config.compile_protos(protos, includes)?;
    }
    Ok(())
}
