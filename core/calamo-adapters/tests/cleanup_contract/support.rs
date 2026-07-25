//! Text metrics of the contract — ports of the prototype's commun.py:
//! typographic normalization, word error rate, boundary-aware term presence.

/// Curly apostrophes, ellipses and non-breaking spaces vary freely between
/// the model and the references; identity is judged past them — but past
/// nothing else: inner whitespace differences stay visible.
pub fn norm_typo(text: &str) -> String {
    text.replace('’', "'")
        .replace('…', "...")
        .replace(['\u{00A0}', '\u{202F}'], " ")
        .trim()
        .to_string()
}

/// Lowercased, unaccented, punctuation-free — the WER alphabet.
pub fn norm_aggressive(text: &str) -> String {
    let folded: String = norm_typo(text)
        .to_lowercase()
        .chars()
        .map(fold_accent)
        .map(|c| if c.is_alphanumeric() { c } else { ' ' })
        .collect();
    collapse_whitespace(&folded)
}

fn collapse_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn fold_accent(c: char) -> char {
    match c {
        'à' | 'â' | 'ä' => 'a',
        'é' | 'è' | 'ê' | 'ë' => 'e',
        'î' | 'ï' => 'i',
        'ô' | 'ö' => 'o',
        'ù' | 'û' | 'ü' => 'u',
        'ç' => 'c',
        _ => c,
    }
}

pub fn word_error_rate(hypothesis: &str, reference: &str) -> f64 {
    let hypothesis = norm_aggressive(hypothesis);
    let reference = norm_aggressive(reference);
    let hypothesis: Vec<&str> = hypothesis.split_whitespace().collect();
    let reference: Vec<&str> = reference.split_whitespace().collect();
    if reference.is_empty() {
        return 0.0;
    }
    levenshtein(&hypothesis, &reference) as f64 / reference.len() as f64
}

fn levenshtein(a: &[&str], b: &[&str]) -> usize {
    let mut previous: Vec<usize> = (0..=b.len()).collect();
    for (i, word_a) in a.iter().enumerate() {
        let mut current = vec![i + 1];
        for (j, word_b) in b.iter().enumerate() {
            let substitution = previous[j] + usize::from(word_a != word_b);
            current.push(substitution.min(previous[j + 1] + 1).min(current[j] + 1));
        }
        previous = current;
    }
    previous[b.len()]
}

/// Word-boundary presence, case- and accent-insensitive: « merger » does not
/// contain « merge ».
pub fn term_present(term: &str, text: &str) -> bool {
    let term = norm_aggressive(term);
    let term: Vec<&str> = term.split_whitespace().collect();
    let text = norm_aggressive(text);
    let text: Vec<&str> = text.split_whitespace().collect();
    !term.is_empty() && text.windows(term.len()).any(|window| window == term)
}

// The prototype's filler list (commun.py); matched on whole normalized words.
const FILLERS: [&str; 6] = ["euh", "um", "uh", "hum", "ben", "bah"];

/// The invariants every vector must satisfy, whatever its expectation.
pub fn invariant_breaches(verbatim: &str, output: &str, glossary: &[String]) -> Vec<String> {
    let mut breaches = Vec::new();
    let normalized = norm_aggressive(output);
    let words: Vec<&str> = normalized.split_whitespace().collect();
    for filler in FILLERS {
        if words.contains(&filler) {
            breaches.push(format!("filler left in the output: « {filler} »"));
        }
    }
    let typographic = norm_typo(output);
    if typographic.starts_with("Voici") {
        breaches.push("output wrapped with a « Voici » preamble".into());
    }
    if typographic.starts_with(['«', '"', '“']) {
        breaches.push("output wrapped in quotes".into());
    }
    for term in glossary {
        if term_present(term, output) && !term_present(term, verbatim) {
            breaches.push(format!(
                "glossary term never dictated yet present: « {term} »"
            ));
        }
    }
    breaches
}
