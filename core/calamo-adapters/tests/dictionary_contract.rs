//! DictionaryRepository contract on the real dictionary.toml adapter, driven
//! by the vectors of fixtures/dictionary-contract.json over temp files —
//! portable and always on, unlike the model-bound contracts.

use std::fs;
use std::path::{Path, PathBuf};

use calamo_adapters::dictionary::TomlDictionaryRepository;
use calamo_core::dictionary::DictionaryEntry;
use calamo_core::ports::{DictionaryLoadError, DictionaryRepository};
use serde::Deserialize;

#[derive(Deserialize)]
struct Contract {
    template: TemplateVector,
    valid: Vec<ValidVector>,
    invalid: Vec<InvalidVector>,
}

#[derive(Deserialize)]
struct TemplateVector {
    entries: Vec<EntryVector>,
}

#[derive(Deserialize)]
struct EntryVector {
    text: String,
    #[serde(default)]
    aliases: Vec<String>,
}

#[derive(Deserialize)]
struct ValidVector {
    id: String,
    toml: Vec<String>,
    entries: Vec<EntryVector>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct InvalidVector {
    id: String,
    toml: Vec<String>,
    line: u32,
    message_contains: String,
}

fn load_contract() -> Contract {
    let path =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/dictionary-contract.json");
    let text = fs::read_to_string(&path).expect("readable dictionary-contract.json");
    serde_json::from_str(&text).expect("well-formed dictionary-contract.json")
}

/// Fresh per test: tests run in parallel within one process.
fn temp_file(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("calamo-dictionary-{}-{test}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    dir.join("dictionary.toml")
}

fn expected_entries(vectors: &[EntryVector]) -> Vec<DictionaryEntry> {
    vectors
        .iter()
        .map(|e| DictionaryEntry::with_aliases(e.text.clone(), e.aliases.clone()))
        .collect()
}

fn load_toml(path: &Path, lines: &[String]) -> Result<Vec<DictionaryEntry>, DictionaryLoadError> {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, lines.join("\n")).unwrap();
    TomlDictionaryRepository::at(path)
        .load()
        .map(|dictionary| dictionary.entries().to_vec())
}

#[test]
fn given_no_file_when_loaded_then_the_template_is_created_and_round_trips_to_its_examples() {
    // Given
    let contract = load_contract();
    let path = temp_file("first-launch");

    // When: the first load creates the auto-documented file
    let loaded = TomlDictionaryRepository::at(&path).load();

    // Then
    assert!(path.is_file(), "dictionary.toml was not created");
    assert_eq!(
        loaded.expect("template loads").entries(),
        expected_entries(&contract.template.entries)
    );
}

#[test]
fn given_each_valid_vector_when_loaded_then_the_entries_match_in_order() {
    // Given
    let contract = load_contract();
    let path = temp_file("valid");

    for vector in &contract.valid {
        // When
        let loaded = load_toml(&path, &vector.toml);

        // Then
        match loaded {
            Ok(entries) => assert_eq!(
                entries,
                expected_entries(&vector.entries),
                "{}: entries differ",
                vector.id
            ),
            Err(error) => panic!("{}: load failed: {error:?}", vector.id),
        }
    }
}

#[test]
fn given_each_invalid_vector_when_loaded_then_the_error_carries_line_and_cause() {
    // Given
    let contract = load_contract();
    let path = temp_file("invalid");

    for vector in &contract.invalid {
        // When
        let error = load_toml(&path, &vector.toml)
            .expect_err(&format!("{}: expected a load failure", vector.id));

        // Then
        assert_eq!(error.line, Some(vector.line), "{}: wrong line", vector.id);
        assert!(
            error.message.contains(&vector.message_contains),
            "{}: « {} » not in « {} »",
            vector.id,
            vector.message_contains,
            error.message
        );
    }
}

#[test]
fn given_an_invalid_file_when_corrected_then_the_next_load_succeeds() {
    // Given
    let contract = load_contract();
    let path = temp_file("corrected");
    let broken = &contract.invalid[0];
    load_toml(&path, &broken.toml).expect_err("broken file fails to load");

    // When
    let fixed = &contract.valid[0];
    let loaded = load_toml(&path, &fixed.toml);

    // Then
    assert_eq!(
        loaded.expect("corrected file loads"),
        expected_entries(&fixed.entries)
    );
}
