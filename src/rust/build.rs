// Record the version of the a5 crate in Cargo.lock for a5_crate_version().
fn main() {
    println!("cargo:rerun-if-changed=Cargo.lock");
    let lock = std::fs::read_to_string("Cargo.lock").unwrap_or_default();
    let mut version = "unknown";
    let mut in_a5 = false;
    for line in lock.lines() {
        if line == "[[package]]" {
            in_a5 = false;
        } else if line == "name = \"a5\"" {
            in_a5 = true;
        } else if in_a5 {
            if let Some(v) = line.strip_prefix("version = \"").and_then(|v| v.strip_suffix('"')) {
                version = v;
                break;
            }
        }
    }
    println!("cargo:rustc-env=A5_CRATE_VERSION={version}");
}
