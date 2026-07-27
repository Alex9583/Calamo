//! Baseline snapshot of the golden run: per-take outputs plus the pinned
//! environment. Drift in either is a failure to diagnose, never a threshold
//! to widen; re-baselining is a deliberate act — delete the file, run once,
//! then pass the admission rite (docs/golden-suites.md).

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Serialize, Deserialize, PartialEq, Clone)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct Environment {
    pub chip: String,
    pub memory_gb: u64,
    pub macos: String,
    pub pins: BTreeMap<String, String>,
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct Baseline {
    pub environment: Environment,
    pub date: String,
    pub outputs: BTreeMap<String, String>,
}

pub fn current_environment(pins: BTreeMap<String, String>) -> Environment {
    Environment {
        chip: stdout_of("sysctl", &["-n", "machdep.cpu.brand_string"]),
        memory_gb: stdout_of("sysctl", &["-n", "hw.memsize"])
            .parse::<u64>()
            .map_or(0, |bytes| bytes / 1_073_741_824),
        macos: stdout_of("sw_vers", &["-productVersion"]),
        pins,
    }
}

fn stdout_of(command: &str, args: &[&str]) -> String {
    Command::new(command)
        .args(args)
        .output()
        .ok()
        .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
        .unwrap_or_default()
}

/// The workspace lock file is the one source of truth for the inference
/// crate's pinned version.
pub fn locked_crate_version(lock_file: &Path, name: &str) -> String {
    let text = std::fs::read_to_string(lock_file).unwrap_or_default();
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if line.trim() == format!("name = \"{name}\"") {
            if let Some(version) = lines
                .next()
                .and_then(|l| l.trim().strip_prefix("version = "))
            {
                return version.trim_matches('"').to_string();
            }
        }
    }
    String::new()
}

/// Absent baseline → bootstrap and announce the rite; present baseline →
/// byte-compare environment and outputs, never rewriting the file.
pub fn check_or_bootstrap(
    path: &PathBuf,
    environment: &Environment,
    outputs: &BTreeMap<String, String>,
) -> Vec<String> {
    let Ok(text) = std::fs::read_to_string(path) else {
        bootstrap(path, environment, outputs);
        return Vec::new();
    };
    let baseline: Baseline = serde_json::from_str(&text)
        .unwrap_or_else(|e| panic!("malformed baseline {}: {e}", path.display()));
    let mut failures = environment_drift(&baseline, environment, path);
    failures.extend(output_drift(&baseline, outputs));
    failures.extend(missing_takes(&baseline, outputs));
    failures
}

fn environment_drift(baseline: &Baseline, current: &Environment, path: &Path) -> Vec<String> {
    if baseline.environment == *current {
        return Vec::new();
    }
    vec![format!(
        "environment drifted from the baseline of {} — any machine or stack \
         change invalidates the calibration; re-baseline (delete {}) after \
         reviewing docs/golden-suites.md",
        baseline.date,
        path.display()
    )]
}

fn output_drift(baseline: &Baseline, outputs: &BTreeMap<String, String>) -> Vec<String> {
    outputs
        .iter()
        .filter_map(|(id, output)| match baseline.outputs.get(id) {
            None => Some(format!("{id}: absent from the baseline")),
            Some(previous) if previous != output => Some(format!(
                "{id}: output drifted from the baseline (variance is a bug to \
                 diagnose):\n  baseline: {previous}\n  now:      {output}"
            )),
            Some(_) => None,
        })
        .collect()
}

fn missing_takes(baseline: &Baseline, outputs: &BTreeMap<String, String>) -> Vec<String> {
    baseline
        .outputs
        .keys()
        .filter(|id| !outputs.contains_key(*id))
        .map(|id| format!("{id}: in the baseline but not in this run"))
        .collect()
}

fn bootstrap(path: &PathBuf, environment: &Environment, outputs: &BTreeMap<String, String>) {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("creating the baseline directory");
    }
    let baseline = Baseline {
        environment: environment.clone(),
        date: stdout_of("date", &["+%Y-%m-%d"]),
        outputs: outputs.clone(),
    };
    std::fs::write(path, serde_json::to_string_pretty(&baseline).unwrap())
        .expect("writing the baseline");
    eprintln!(
        "[cleanup-golden] baseline bootstrapped at {} — run the admission rite \
         (5 consecutive identical runs) before trusting it",
        path.display()
    );
}
