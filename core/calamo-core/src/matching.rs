//! Fuzzy word matching shared by SpellingEnforcement and the Dictionary
//! views. Near-exact by design: fixes spellings, never repairs phonetics.

use crate::dictionary::DictionaryEntry;

pub(crate) const SIMILARITY_THRESHOLD: f64 = 0.90;
/// Short terms only match exactly — "pour" must never become "PR".
const SHORT_TERM_MAX_CHARS: usize = 4;

/// A canonical or alias in comparison form, with the spelling it rewrites to.
pub(crate) struct PreparedTerm<'a> {
    pub(crate) canonical: &'a str,
    pub(crate) norm: String,
    pub(crate) token_count: usize,
    requires_exact: bool,
}

impl PreparedTerm<'_> {
    pub(crate) fn matches(&self, candidate: &str) -> bool {
        self.matches_exactly(candidate) || self.matches_fuzzily(candidate)
    }

    pub(crate) fn matches_exactly(&self, candidate: &str) -> bool {
        candidate == self.norm
    }

    pub(crate) fn matches_fuzzily(&self, candidate: &str) -> bool {
        if self.requires_exact {
            return false;
        }
        // Length difference lower-bounds the distance; strsim's own formula
        // keeps the skip consistent with it at the threshold.
        let (c_len, t_len) = (candidate.chars().count(), self.norm.chars().count());
        let max_len = c_len.max(t_len);
        let best_possible = 1.0 - c_len.abs_diff(t_len) as f64 / max_len as f64;
        if best_possible < SIMILARITY_THRESHOLD {
            return false;
        }
        strsim::normalized_levenshtein(candidate, &self.norm) >= SIMILARITY_THRESHOLD
    }
}

/// The terms of one entry, canonical first, then aliases in declared order.
pub(crate) fn entry_terms(entry: &DictionaryEntry) -> impl Iterator<Item = PreparedTerm<'_>> {
    std::iter::once(entry.canonical_text())
        .chain(entry.aliases().iter().map(String::as_str))
        .filter_map(|text| {
            let token_norms = normalized_words(text);
            if token_norms.is_empty() {
                return None;
            }
            let letter_count: usize = token_norms.iter().map(|t| t.chars().count()).sum();
            Some(PreparedTerm {
                canonical: entry.canonical_text(),
                token_count: token_norms.len(),
                norm: token_norms.join(" "),
                requires_exact: letter_count <= SHORT_TERM_MAX_CHARS,
            })
        })
}

pub(crate) fn normalized_words(text: &str) -> Vec<String> {
    word_spans(text)
        .iter()
        .map(|&(s, e)| normalize(&text[s..e]))
        .collect()
}

pub(crate) fn occurs_in(word_norms: &[String], term: &PreparedTerm<'_>) -> bool {
    let n = term.token_count;
    (0..word_norms.len().saturating_sub(n - 1))
        .any(|i| term.matches(&word_norms[i..i + n].join(" ")))
}

/// Lowercase, Latin diacritics folded: spellings match modulo case/accents.
pub(crate) fn normalize(word: &str) -> String {
    let mut out = String::with_capacity(word.len());
    for c in word.chars().flat_map(char::to_lowercase) {
        match c {
            'à' | 'â' | 'ä' | 'á' | 'ã' | 'å' => out.push('a'),
            'é' | 'è' | 'ê' | 'ë' => out.push('e'),
            'î' | 'ï' | 'í' | 'ì' => out.push('i'),
            'ô' | 'ö' | 'ó' | 'ò' | 'õ' => out.push('o'),
            'ù' | 'û' | 'ü' | 'ú' => out.push('u'),
            'ç' => out.push('c'),
            'ñ' => out.push('n'),
            'ÿ' | 'ý' => out.push('y'),
            'œ' => out.push_str("oe"),
            'æ' => out.push_str("ae"),
            _ => out.push(c),
        }
    }
    out
}

/// Alphanumeric runs; apostrophes and hyphens separate words, so French
/// elisions ("l'adapter") expose the word behind them.
pub(crate) fn word_spans(text: &str) -> Vec<(usize, usize)> {
    let mut spans = Vec::new();
    let mut current: Option<usize> = None;
    for (i, c) in text.char_indices() {
        if c.is_alphanumeric() {
            current.get_or_insert(i);
        } else if let Some(start) = current.take() {
            spans.push((start, i));
        }
    }
    if let Some(start) = current {
        spans.push((start, text.len()));
    }
    spans
}
