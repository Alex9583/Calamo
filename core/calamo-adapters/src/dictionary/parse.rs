//! TOML → Dictionary with the error's line number preserved: the shell's
//! notification must point the user at the line to fix.

use calamo_core::dictionary::{Dictionary, DictionaryEntry, DictionaryError};
use calamo_core::ports::DictionaryLoadError;
use serde::Deserialize;
use toml::Spanned;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RawDictionary {
    #[serde(default)]
    entries: Vec<Spanned<RawEntry>>,
}

/// deny_unknown_fields: a misspelled key must fail loudly, not drop entries.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RawEntry {
    text: String,
    #[serde(default)]
    aliases: Vec<String>,
}

pub(super) fn parse(content: &str) -> Result<Dictionary, DictionaryLoadError> {
    let raw: RawDictionary =
        toml::from_str(content).map_err(|error| syntax_error(content, &error))?;
    let entries = raw
        .entries
        .iter()
        .map(|entry| {
            DictionaryEntry::with_aliases(
                entry.get_ref().text.clone(),
                entry.get_ref().aliases.clone(),
            )
        })
        .collect();
    Dictionary::new(entries).map_err(|error| invariant_error(content, &raw.entries, &error))
}

fn syntax_error(content: &str, error: &toml::de::Error) -> DictionaryLoadError {
    DictionaryLoadError {
        line: error.span().map(|span| line_at(content, span.start)),
        message: error.message().to_string(),
    }
}

/// The second occurrence is the one the user removes.
fn invariant_error(
    content: &str,
    entries: &[Spanned<RawEntry>],
    error: &DictionaryError,
) -> DictionaryLoadError {
    let DictionaryError::DuplicateCanonicalText { canonical_text } = error;
    let line = entries
        .iter()
        .filter(|entry| entry.get_ref().text == *canonical_text)
        .nth(1)
        .map(|entry| line_at(content, entry.span().start));
    DictionaryLoadError {
        line,
        message: error.to_string(),
    }
}

fn line_at(content: &str, offset: usize) -> u32 {
    let newlines = content.as_bytes()[..offset.min(content.len())]
        .iter()
        .filter(|byte| **byte == b'\n')
        .count();
    u32::try_from(newlines + 1).unwrap_or(u32::MAX)
}
