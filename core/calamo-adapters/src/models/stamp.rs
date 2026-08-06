//! The verification cache: one line per file whose bytes were hash-checked,
//! keyed by size + mtime so any touch re-triggers the hash. Losing or
//! garbling it costs a re-hash, never data — malformed lines are dropped.

use std::collections::HashMap;

use super::store::FileMeta;

const HEADER: &str = "calamo-store-v1";

#[derive(Default)]
pub(crate) struct Stamp {
    entries: HashMap<String, Entry>,
}

struct Entry {
    size: u64,
    modified_ms: i64,
    sha256: String,
}

impl Stamp {
    pub(crate) fn parse(contents: Option<&str>) -> Self {
        let mut lines = match contents {
            Some(text) => text.lines(),
            None => return Self::default(),
        };
        if lines.next() != Some(HEADER) {
            return Self::default();
        }
        let entries = lines.filter_map(parse_line).collect();
        Self { entries }
    }

    pub(crate) fn covers(&self, path: &str, sha256: &str, meta: &FileMeta) -> bool {
        self.entries.get(path).is_some_and(|e| {
            e.sha256 == sha256 && e.size == meta.size && e.modified_ms == meta.modified_ms
        })
    }

    pub(crate) fn record(&mut self, path: &str, sha256: &str, meta: &FileMeta) {
        self.entries.insert(
            path.to_string(),
            Entry {
                size: meta.size,
                modified_ms: meta.modified_ms,
                sha256: sha256.to_string(),
            },
        );
    }

    pub(crate) fn render(&self) -> String {
        let mut lines: Vec<String> = self
            .entries
            .iter()
            .map(|(path, e)| format!("{} {} {} {path}", e.size, e.modified_ms, e.sha256))
            .collect();
        lines.sort();
        format!("{HEADER}\n{}\n", lines.join("\n"))
    }
}

fn parse_line(line: &str) -> Option<(String, Entry)> {
    let mut parts = line.splitn(4, ' ');
    let size = parts.next()?.parse().ok()?;
    let modified_ms = parts.next()?.parse().ok()?;
    let sha256 = parts.next()?.to_string();
    let path = parts.next()?.to_string();
    Some((
        path,
        Entry {
            size,
            modified_ms,
            sha256,
        },
    ))
}
