//! Text metrics shared by the contract and golden harnesses — ports of the
//! prototype's commun.py and score.py: typographic normalization, word error
//! rate, boundary-aware term presence, and the corpus's number/filler
//! normalization layer.

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

fn levenshtein<T: PartialEq>(a: &[T], b: &[T]) -> usize {
    let mut previous: Vec<usize> = (0..=b.len()).collect();
    for (i, item_a) in a.iter().enumerate() {
        let mut current = vec![i + 1];
        for (j, item_b) in b.iter().enumerate() {
            let substitution = previous[j] + usize::from(item_a != item_b);
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

/// Case-sensitive word-boundary presence on typographically normalized text —
/// the check behind the prompt's « Exact spellings » rule.
pub fn term_exact(term: &str, text: &str) -> bool {
    let term = norm_typo(term);
    let text = norm_typo(text);
    if term.is_empty() {
        return false;
    }
    let boundary = |c: Option<char>| c.is_none_or(|c| !c.is_alphanumeric());
    text.match_indices(&term).any(|(start, matched)| {
        boundary(text[..start].chars().next_back())
            && boundary(text[start + matched.len()..].chars().next())
    })
}

/// Normalized Levenshtein similarity on the characters of number/filler-
/// normalized tokens — the golden suites' per-take fidelity metric. Case,
/// punctuation, digit/word number variants and hesitation fillers are
/// out of scope by design: exact spellings have their own hard assertion.
pub fn levenshtein_similarity04(a: &str, b: &str) -> f64 {
    let a: Vec<char> = tokenize04(a).join(" ").chars().collect();
    let b: Vec<char> = tokenize04(b).join(" ").chars().collect();
    let longest = a.len().max(b.len());
    if longest == 0 {
        return 1.0;
    }
    1.0 - levenshtein(&a, &b) as f64 / longest as f64
}

// The corpus's normalization layer (prototype 04): the manifest writes
// numbers as spoken words while the ASR emits digits — both sides meet here.
const FILLERS04: [&str; 6] = ["euh", "um", "uh", "hum", "mmh", "hmm"];
const NUM_MAP: [(&str, &str); 11] = [
    ("dix", "10"),
    ("quinze", "15"),
    ("quatorze", "14"),
    ("trente", "30"),
    ("cinq", "5"),
    ("h", "heures"),
    ("nine", "9"),
    ("twentieth", "20"),
    ("three", "3"),
    ("thirty", "30"),
    ("ninety", "90"),
];

fn tokenize04(text: &str) -> Vec<String> {
    const PUNCT: &[char] = &[
        '.', ',', ';', ':', '!', '?', '«', '»', '“', '”', '"', '(', ')', '…', '-',
    ];
    let stripped: String = norm_typo(text)
        .to_lowercase()
        .chars()
        .map(|c| if PUNCT.contains(&c) { ' ' } else { c })
        .collect();
    let mut tokens: Vec<String> = split_hours(&stripped)
        .split_whitespace()
        .map(strip_elision)
        .map(map_number)
        .collect();
    tokens = join_am_pm(tokens);
    tokens.retain(|t| !FILLERS04.contains(&t.as_str()));
    tokens
}

/// « 14h30 » → « 14 heures 30 ».
fn split_hours(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let mut out = String::with_capacity(text.len());
    for (i, &c) in chars.iter().enumerate() {
        let between_digits = i > 0
            && i + 1 < chars.len()
            && chars[i - 1].is_ascii_digit()
            && chars[i + 1].is_ascii_digit();
        if c == 'h' && between_digits {
            out.push_str(" heures ");
        } else {
            out.push(c);
        }
    }
    out
}

fn strip_elision(token: &str) -> &str {
    if token.len() > 1 {
        token.strip_suffix('\'').unwrap_or(token)
    } else {
        token
    }
}

fn map_number(token: &str) -> String {
    NUM_MAP
        .iter()
        .find(|(from, _)| *from == token)
        .map_or_else(|| token.to_string(), |(_, to)| to.to_string())
}

/// « a.m. » survives punctuation stripping as two tokens.
fn join_am_pm(tokens: Vec<String>) -> Vec<String> {
    let mut out = Vec::with_capacity(tokens.len());
    let mut iter = tokens.into_iter().peekable();
    while let Some(token) = iter.next() {
        if (token == "a" || token == "p") && iter.peek().is_some_and(|next| next == "m") {
            iter.next();
            out.push(format!("{token}m"));
        } else {
            out.push(token);
        }
    }
    out
}

// The prototype's filler list (commun.py); matched on whole normalized words.
const FILLERS: [&str; 6] = ["euh", "um", "uh", "hum", "ben", "bah"];

/// A glossary term may only appear if the take itself dictated it.
pub fn never_dictated_breaches(verbatim: &str, output: &str, glossary: &[String]) -> Vec<String> {
    glossary
        .iter()
        .filter(|term| term_present(term, output) && !term_present(term, verbatim))
        .map(|term| format!("glossary term never dictated yet present: « {term} »"))
        .collect()
}

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
    breaches.extend(never_dictated_breaches(verbatim, output, glossary));
    breaches
}
