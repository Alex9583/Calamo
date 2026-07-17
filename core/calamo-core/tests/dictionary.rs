//! Behavioral tests for the Dictionary aggregate, through its public
//! interface only.

use calamo_core::dictionary::{Dictionary, DictionaryEntry, DictionaryError};

mod construction {
    use super::*;

    #[test]
    fn given_entries_when_building_then_declaration_order_is_kept_as_priority() {
        // Given
        let entries = vec![
            DictionaryEntry::new("GitHub"),
            DictionaryEntry::new("Jira"),
            DictionaryEntry::new("PR"),
        ];

        // When
        let dictionary = Dictionary::new(entries).unwrap();

        // Then
        let canonicals: Vec<&str> = dictionary
            .entries()
            .iter()
            .map(|e| e.canonical_text())
            .collect();
        assert_eq!(canonicals, ["GitHub", "Jira", "PR"]);
    }

    #[test]
    fn given_a_duplicate_canonical_when_building_then_the_dictionary_is_refused() {
        // Given
        let entries = vec![
            DictionaryEntry::new("GitHub"),
            DictionaryEntry::new("Jira"),
            DictionaryEntry::new("GitHub"),
        ];

        // When
        let result = Dictionary::new(entries);

        // Then
        assert_eq!(
            result.err(),
            Some(DictionaryError::DuplicateCanonicalText {
                canonical_text: "GitHub".to_string()
            })
        );
    }
}

mod boost_list {
    use super::*;

    #[test]
    fn given_a_small_dictionary_when_deriving_the_boost_list_then_every_canonical_and_alias_is_boosted(
    ) {
        // Given
        let dictionary = Dictionary::new(vec![
            DictionaryEntry::with_aliases("GitHub", ["github", "git hub"]),
            DictionaryEntry::new("Jira"),
        ])
        .unwrap();

        // When
        let boost = dictionary.boost_list();

        // Then
        assert_eq!(boost.len(), 2);
        assert_eq!(boost[0].canonical_text(), "GitHub");
        assert_eq!(boost[0].aliases(), ["github", "git hub"]);
        assert_eq!(boost[1].canonical_text(), "Jira");
        assert_eq!(boost[1].aliases(), [""; 0]);
    }

    #[test]
    fn given_150_entries_when_deriving_the_boost_list_then_only_the_first_100_are_boosted() {
        // Given
        let entries: Vec<DictionaryEntry> = (0..150)
            .map(|i| DictionaryEntry::new(format!("Entry{i:03}")))
            .collect();
        let dictionary = Dictionary::new(entries).unwrap();

        // When
        let boost = dictionary.boost_list();

        // Then
        assert_eq!(boost.len(), 100);
        assert_eq!(boost[0].canonical_text(), "Entry000");
        assert_eq!(boost[99].canonical_text(), "Entry099");
    }
}

mod prompt_glossary {
    use super::*;

    #[test]
    fn given_at_most_50_entries_when_deriving_the_glossary_then_every_canonical_is_listed() {
        // Given
        let dictionary = Dictionary::new(vec![
            DictionaryEntry::with_aliases("GitHub", ["github"]),
            DictionaryEntry::new("Jira"),
            DictionaryEntry::new("PR"),
        ])
        .unwrap();

        // When
        let glossary = dictionary.prompt_glossary("un transcript quelconque");

        // Then
        assert_eq!(glossary, ["GitHub", "Jira", "PR"]);
    }

    #[test]
    fn given_more_than_50_entries_when_deriving_the_glossary_then_only_entries_heard_in_the_transcript_are_added(
    ) {
        // Given
        let mut entries: Vec<DictionaryEntry> = (0..50)
            .map(|i| DictionaryEntry::new(format!("Entry{i:02}")))
            .collect();
        entries.push(DictionaryEntry::with_aliases("OpenShift", ["open shift"]));
        entries.push(DictionaryEntry::new("Kubernetes"));
        entries.push(DictionaryEntry::new("Terraform"));
        let dictionary = Dictionary::new(entries).unwrap();

        // When
        let glossary = dictionary.prompt_glossary("on déploie sur open shift et kubernete demain");

        // Then: the first 50 stay; beyond them, only what the transcript contains
        assert_eq!(glossary.len(), 52);
        assert_eq!(glossary[0], "Entry00");
        assert_eq!(glossary[49], "Entry49");
        assert!(
            glossary.contains(&"OpenShift"),
            "alias heard in the transcript"
        );
        assert!(
            glossary.contains(&"Kubernetes"),
            "fuzzy neighbor of 'kubernete'"
        );
        assert!(!glossary.contains(&"Terraform"), "never uttered");
    }
}
