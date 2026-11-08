//! win2lin-verify: SHA-256 bundle verifier/writer (optional Rust accelerator).
//! Format: <hex> *<relative-path-with-slashes>  (sha256sum-compatible)
use sha2::{Digest, Sha256};
use std::fs;
use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const META: &[&str] = &[
    "inventory.json",
    "manifest.csv",
    "copy_result.json",
    "log.txt",
    "copy_log.txt",
    "migration-report.md",
    "migration-plan.json",
    "migration-report.md",
    "recovery-checklist.md",
];

fn hash_file(path: &Path) -> std::io::Result<String> {
    let mut f = fs::File::open(path)?;
    let mut buf = vec![0u8; 1024 * 1024];
    let mut hasher = Sha256::new();
    loop {
        let n = f.read(&mut buf)?;
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    Ok(hasher.finalize().iter().map(|b| format!("{b:02x}")).collect())
}

fn rel_slash(bundle: &Path, file: &Path) -> String {
    file.strip_prefix(bundle)
        .unwrap_or(file)
        .to_string_lossy()
        .replace('\\', "/")
}

fn collect_meta(bundle: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    for m in META {
        let p = bundle.join(m);
        if p.is_file() { out.push(p); }
    }
    if let Ok(rd) = fs::read_dir(bundle) {
        for e in rd.flatten() {
            let p = e.path();
            if p.is_file() {
                if let Some(n) = p.file_name().and_then(|s| s.to_str()) {
                    if n.starts_with("robocopy_") && n.ends_with(".log") { out.push(p); }
                }
            }
        }
    }
    out
}

fn collect_payload(bundle: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    for d in ["C_DRIVE", "D_DRIVE"] {
        let dp = bundle.join(d);
        if !dp.is_dir() { continue; }
        // iterative walk, skip *.part.* (incomplete copies)
        let mut stack = vec![dp];
        while let Some(dir) = stack.pop() {
            let rd = match fs::read_dir(&dir) { Ok(r) => r, Err(_) => continue };
            for e in rd.flatten() {
                let p = e.path();
                if p.is_dir() {
                    // do not follow symlink dirs blindly; treat as files skipped
                    if p.symlink_metadata().map(|m| m.file_type().is_symlink()).unwrap_or(false) {
                        continue;
                    }
                    stack.push(p);
                } else if p.is_file() {
                    if let Some(n) = p.file_name().and_then(|s| s.to_str()) {
                        if n.contains(".part.") { continue; }
                    }
                    out.push(p);
                }
            }
        }
    }
    out
}

fn cmd_write(bundle: &Path, include_payload: bool) -> i32 {
    let mut files = collect_meta(bundle);
    if include_payload {
        files.extend(collect_payload(bundle));
    }
    let mut paths: Vec<PathBuf> = files;
    paths.sort_by_key(|p| rel_slash(bundle, p));
    paths.dedup();
    let mut lines = Vec::new();
    for f in &paths {
        match hash_file(f) {
            Ok(h) => lines.push(format!("{} *{}", h, rel_slash(bundle, f))),
            Err(e) => eprintln!("ERROR hashing {}: {}", f.display(), e),
        }
    }
    let out_path = bundle.join("checksums.sha256");
    let body = lines.join("\n") + "\n";
    if let Err(e) = fs::write(&out_path, body) {
        eprintln!("ERROR writing {}: {}", out_path.display(), e);
        return 1;
    }
    println!("Wrote {} checksums -> {}", lines.len(), out_path.display());
    if !include_payload {
        println!("Note: payload (C_DRIVE/D_DRIVE) not included. Use --include-payload for full checksums (slow).");
    }
    0
}

fn cmd_verify(bundle: &Path, checksum_file: Option<&Path>) -> i32 {
    let cf = checksum_file.map(|p| p.to_path_buf()).unwrap_or_else(|| bundle.join("checksums.sha256"));
    let f = match fs::File::open(&cf) {
        Ok(f) => f,
        Err(e) => { eprintln!("ERROR: checksum file not found {}: {}", cf.display(), e); return 1; }
    };
    let (mut ok, mut bad, mut missing) = (0u64, 0u64, 0u64);
    let reader = BufReader::new(f);
    for line in reader.lines() {
        let line = match line { Ok(l) => l, Err(_) => continue };
        let t = line.trim();
        if t.is_empty() || t.starts_with('#') { continue; }
        // "<hex> *<path>" or "<hex>  <path>" or "<hex> <path>"
        let mut parts = t.splitn(2, ' ');
        let hex = match parts.next() { Some(h) => h.trim(), None => continue };
        let rest = match parts.next() { Some(r) => r.trim().trim_start_matches('*').trim(), None => continue };
        if hex.len() != 64 || !hex.chars().all(|c| c.is_ascii_hexdigit()) { continue; }
        let rel = rest.replace('/', "\\");
        let target = bundle.join(&rel);
        if !target.is_file() {
            println!("MISSING: {}", rel);
            missing += 1;
            continue;
        }
        match hash_file(&target) {
            Ok(actual) if actual.eq_ignore_ascii_case(hex) => { ok += 1; }
            Ok(actual) => { println!("BAD: {} (expected {} got {})", rel, hex, actual); bad += 1; }
            Err(e) => { println!("BAD: {} ({})", rel, e); bad += 1; }
        }
    }
    println!("Verify: OK={} BAD={} MISSING={} ({})", ok, bad, missing, cf.display());
    if bad > 0 || missing > 0 { 2 } else { 0 }
}

fn parse_args() -> Result<(String, PathBuf, Option<PathBuf>, bool), String> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() || args.iter().any(|a| a == "-h" || a == "--help") {
        return Err("usage: win2lin-verify <write|verify> --bundle <path> [--checksum-file <path>] [--include-payload]".into());
    }
    let mode = args[0].clone();
    if mode != "write" && mode != "verify" {
        return Err(format!("unknown mode: {}", mode));
    }
    let mut bundle: Option<PathBuf> = None;
    let mut checksum_file: Option<PathBuf> = None;
    let mut include_payload = false;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--bundle" => { bundle = args.get(i + 1).map(PathBuf::from); i += 2; }
            "--checksum-file" => { checksum_file = args.get(i + 1).map(PathBuf::from); i += 2; }
            "--include-payload" => { include_payload = true; i += 1; }
            other => return Err(format!("unknown arg: {}", other)),
        }
    }
    let bundle = bundle.ok_or_else(|| "missing required --bundle <path>".to_string())?;
    Ok((mode, bundle, checksum_file, include_payload))
}

fn main() -> ExitCode {
    let (mode, bundle, checksum_file, include_payload) = match parse_args() {
        Ok(v) => v,
        Err(e) => { eprintln!("{}", e); return ExitCode::from(1); }
    };
    if !bundle.is_dir() {
        eprintln!("ERROR: bundle not found: {}", bundle.display());
        return ExitCode::from(1);
    }
    let code = if mode == "write" {
        cmd_write(&bundle, include_payload)
    } else {
        cmd_verify(&bundle, checksum_file.as_deref())
    };
    ExitCode::from(code as u8)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn empty_dir_meta_is_empty() {
        let dir = std::env::temp_dir().join("win2lin-test-empty");
        let _ = fs::create_dir_all(&dir);
        assert!(collect_meta(&dir).is_empty());
    }
    #[test]
    fn hash_hello() {
        let dir = std::env::temp_dir().join("win2lin-test-hash");
        let _ = fs::create_dir_all(&dir);
        let f = dir.join("a.txt");
        fs::write(&f, b"hello").unwrap();
        // sha256("hello") known value
        assert_eq!(hash_file(&f).unwrap(), "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
    }
    #[test]
    fn rel_slash_converts() {
        let b = Path::new(r"C:\bundle");
        let f = Path::new(r"C:\bundle\C_DRIVE\file.txt");
        assert_eq!(rel_slash(b, f), "C_DRIVE/file.txt");
    }
}
