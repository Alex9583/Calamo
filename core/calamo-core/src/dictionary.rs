//! The Dictionary aggregate: the user's ordered list of enforced spellings.
//! Order is priority; canonical texts are unique.

use crate::matching;
use std::collections::HashSet;
use std::fmt;

const BOOST_LIST_MAX_ENTRIES: usize = 100;
const PROMPT_GLOSSARY_FIXED_ENTRIES: usize = 50;

/// One enforced spelling with its spoken aliases.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DictionaryEntry {
    canonical_text: String,
    aliases: Vec<String>,
}

impl DictionaryEntry {
    pub fn new(canonical_text: impl Into<String>) -> Self {
        Self {
            canonical_text: canonical_text.into(),
            aliases: Vec::new(),
        }
    }

    pub fn with_aliases<I, S>(canonical_text: impl Into<String>, aliases: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        Self {
            canonical_text: canonical_text.into(),
            aliases: aliases.into_iter().map(Into::into).collect(),
        }
    }

    pub fn canonical_text(&self) -> &str {
        &self.canonical_text
    }

    pub fn aliases(&self) -> &[String] {
        &self.aliases
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DictionaryError {
    DuplicateCanonicalText { canonical_text: String },
}

impl fmt::Display for DictionaryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DuplicateCanonicalText { canonical_text } => {
                write!(f, "duplicate canonical text: {canonical_text}")
            }
        }
    }
}

impl std::error::Error for DictionaryError {}

/// The user's ordered list of DictionaryEntries.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Dictionary {
    entries: Vec<DictionaryEntry>,
}

impl Dictionary {
    pub fn new(entries: Vec<DictionaryEntry>) -> Result<Self, DictionaryError> {
        let mut seen = HashSet::new();
        for entry in &entries {
            if !seen.insert(entry.canonical_text.as_str()) {
                return Err(DictionaryError::DuplicateCanonicalText {
                    canonical_text: entry.canonical_text.clone(),
                });
            }
        }
        Ok(Self { entries })
    }

    pub fn entries(&self) -> &[DictionaryEntry] {
        &self.entries
    }

    /// Biasing view for speech recognition: the first 100 entries at most;
    /// the rest stays covered by the prompt glossary and spelling enforcement.
    pub fn boost_list(&self) -> &[DictionaryEntry] {
        &self.entries[..self.entries.len().min(BOOST_LIST_MAX_ENTRIES)]
    }

    /// The transcript-independent part of every prompt glossary — what a
    /// background prompt-prefix warm-up can precompute.
    pub fn fixed_prompt_glossary(&self) -> Vec<&str> {
        self.entries
            .iter()
            .take(PROMPT_GLOSSARY_FIXED_ENTRIES)
            .map(|e| e.canonical_text())
            .collect()
    }

    /// Cleanup-prompt view: the first 50 canonicals, plus — beyond them —
    /// only entries fuzzily present in the transcript.
    pub fn prompt_glossary(&self, raw_transcript: &str) -> Vec<&str> {
        let mut glossary = self.fixed_prompt_glossary();

        if self.entries.len() > PROMPT_GLOSSARY_FIXED_ENTRIES {
            let word_norms = matching::normalized_words(raw_transcript);
            glossary.extend(
                self.entries[PROMPT_GLOSSARY_FIXED_ENTRIES..]
                    .iter()
                    .filter(|entry| {
                        matching::entry_terms(entry).any(|t| matching::occurs_in(&word_norms, &t))
                    })
                    .map(|e| e.canonical_text()),
            );
        }
        glossary
    }
}
