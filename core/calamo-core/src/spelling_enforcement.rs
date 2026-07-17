//! The deterministic domain service applying Dictionary spellings —
//! the only stage that guarantees a spelling.

use crate::dictionary::Dictionary;
use crate::matching::{self, PreparedTerm};

/// Rewrites words matching a Dictionary term into its canonical spelling, at
/// word boundaries. An exact match beats every fuzzy match — an exactly-spelled
/// word never drifts to a near neighbor — and entry order breaks ties.
pub fn enforce(text: &str, dictionary: &Dictionary) -> String {
    let words = matching::word_spans(text);
    let norms = matching::normalized_words(text);
    let terms = DictionaryTerms::of(dictionary);

    let mut out = String::with_capacity(text.len());
    let mut cursor = 0;
    let mut i = 0;
    while i < words.len() {
        match terms.winning_term_at(&norms, i) {
            Some(term) => {
                out.push_str(&text[cursor..words[i].0]);
                out.push_str(term.canonical);
                cursor = words[i + term.token_count - 1].1;
                i += term.token_count;
            }
            None => i += 1,
        }
    }
    out.push_str(&text[cursor..]);
    out
}

/// Every term of the dictionary in priority order, with the distinct span
/// widths to try at each word.
struct DictionaryTerms<'a> {
    terms: Vec<PreparedTerm<'a>>,
    span_widths: Vec<usize>,
}

impl<'a> DictionaryTerms<'a> {
    fn of(dictionary: &'a Dictionary) -> Self {
        let terms: Vec<PreparedTerm<'a>> = dictionary
            .entries()
            .iter()
            .flat_map(matching::entry_terms)
            .collect();
        let mut span_widths: Vec<usize> = terms.iter().map(|t| t.token_count).collect();
        span_widths.sort_unstable();
        span_widths.dedup();
        Self { terms, span_widths }
    }

    fn winning_term_at(&self, norms: &[String], i: usize) -> Option<&PreparedTerm<'a>> {
        let candidates = self.candidate_spans_at(norms, i);
        let candidate = |width: usize| {
            candidates
                .iter()
                .find(|&&(w, _)| w == width)
                .map(|(_, joined)| joined.as_str())
        };
        self.terms
            .iter()
            .find(|t| candidate(t.token_count).is_some_and(|c| t.matches_exactly(c)))
            .or_else(|| {
                self.terms
                    .iter()
                    .find(|t| candidate(t.token_count).is_some_and(|c| t.matches_fuzzily(c)))
            })
    }

    fn candidate_spans_at(&self, norms: &[String], i: usize) -> Vec<(usize, String)> {
        self.span_widths
            .iter()
            .filter(|&&width| i + width <= norms.len())
            .map(|&width| (width, norms[i..i + width].join(" ")))
            .collect()
    }
}
