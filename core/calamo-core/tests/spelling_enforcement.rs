//! Behavioral tests for the SpellingEnforcement domain service, through its
//! public interface only.

use calamo_core::dictionary::{Dictionary, DictionaryEntry};
use calamo_core::spelling_enforcement::enforce;

fn dictionary(entries: Vec<DictionaryEntry>) -> Dictionary {
    Dictionary::new(entries).unwrap()
}

mod exact_spelling {
    use super::*;

    #[test]
    fn given_a_term_in_the_wrong_case_when_enforcing_then_the_canonical_case_is_restored() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("GitHub")]);

        // When
        let lowercased = enforce("Sur github, tout est versionné.", &dict);
        let capitalized = enforce("Github m'a notifié", &dict);

        // Then
        assert_eq!(lowercased, "Sur GitHub, tout est versionné.");
        assert_eq!(capitalized, "GitHub m'a notifié");
    }

    #[test]
    fn given_an_unaccented_form_when_enforcing_then_the_accented_canonical_is_applied() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("Bézier")]);

        // When
        let unaccented = enforce("une courbe de bezier", &dict);
        let accented = enforce("une courbe de bézier", &dict);

        // Then
        assert_eq!(unaccented, "une courbe de Bézier");
        assert_eq!(accented, "une courbe de Bézier");
    }

    #[test]
    fn given_a_spoken_alias_when_enforcing_then_the_canonical_spelling_replaces_it() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::with_aliases(
            "GitHub",
            ["guithub", "guitte hub"],
        )]);

        // When
        let enforced = enforce("pousse sur guithub", &dict);

        // Then
        assert_eq!(enforced, "pousse sur GitHub");
    }

    #[test]
    fn given_a_multi_word_alias_when_enforcing_then_the_whole_span_is_replaced() {
        // Given
        let dict = dictionary(vec![
            DictionaryEntry::with_aliases("GitHub", ["guithub", "guitte hub"]),
            DictionaryEntry::with_aliases("macOS", ["Mac OS", "mac os"]),
        ]);

        // When
        let enforced = enforce("ça marche sur mac os et sur guitte hub", &dict);

        // Then
        assert_eq!(enforced, "ça marche sur macOS et sur GitHub");
    }

    #[test]
    fn given_a_french_elision_when_enforcing_then_the_word_behind_it_is_matched() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("iPhone")]);

        // When
        let straight = enforce("l'iphone est chargé", &dict);
        let typographic = enforce("l’iphone est chargé", &dict);
        let contraction = enforce("la coque d'iphone", &dict);

        // Then
        assert_eq!(straight, "l'iPhone est chargé");
        assert_eq!(typographic, "l’iPhone est chargé");
        assert_eq!(contraction, "la coque d'iPhone");
    }
}

mod fuzzy_spelling {
    use super::*;

    #[test]
    fn given_a_near_miss_on_a_long_term_when_enforcing_then_it_is_corrected_at_the_090_threshold() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("Kubernetes")]);

        // When: "kubernete" — 1 - 1/10 = 0.90, exactly at the threshold
        let enforced = enforce("déployé sur kubernete hier", &dict);

        // Then
        assert_eq!(enforced, "déployé sur Kubernetes hier");
    }

    #[test]
    fn given_a_plural_below_the_threshold_when_enforcing_then_the_users_word_is_kept() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("Ticket")]);

        // When: "tickets" — 1 - 1/7 ≈ 0.857, below the threshold
        let plural = enforce("trois tickets ouverts", &dict);
        let singular = enforce("un ticket ouvert", &dict);

        // Then
        assert_eq!(plural, "trois tickets ouverts");
        assert_eq!(singular, "un Ticket ouvert");
    }
}

mod short_term_guard {
    use super::*;

    #[test]
    fn given_the_entry_pr_when_enforcing_a_close_word_then_pour_is_never_rewritten() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("PR")]);

        // When
        let enforced = enforce("c'est pour demain", &dict);

        // Then
        assert_eq!(enforced, "c'est pour demain");
    }

    #[test]
    fn given_the_entry_pr_when_enforcing_the_exact_word_then_only_its_case_is_fixed() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("PR")]);

        // When
        let enforced = enforce("relis la pr avant", &dict);

        // Then
        assert_eq!(enforced, "relis la PR avant");
    }
}

mod priority {
    use super::*;

    #[test]
    fn given_two_entries_claiming_the_same_word_when_enforcing_then_the_earlier_entry_wins() {
        // Given
        let macos_first = dictionary(vec![
            DictionaryEntry::with_aliases("macOS", ["mac"]),
            DictionaryEntry::new("Mac"),
        ]);
        let mac_first = dictionary(vec![
            DictionaryEntry::new("Mac"),
            DictionaryEntry::with_aliases("macOS", ["mac"]),
        ]);

        // When
        let macos_wins = enforce("sur mac uniquement", &macos_first);
        let mac_wins = enforce("sur mac uniquement", &mac_first);

        // Then
        assert_eq!(macos_wins, "sur macOS uniquement");
        assert_eq!(mac_wins, "sur Mac uniquement");
    }

    #[test]
    fn given_an_exact_match_of_a_later_entry_when_enforcing_then_it_beats_an_earlier_fuzzy_match() {
        // Given
        let dict = dictionary(vec![
            DictionaryEntry::new("Release2025"),
            DictionaryEntry::new("Release2026"),
        ]);

        // When: within fuzzy reach of "Release2025", but exactly "Release2026"
        let enforced = enforce("prévu pour release2026", &dict);

        // Then
        assert_eq!(enforced, "prévu pour Release2026");
    }
}

mod pass_through {
    use super::*;

    #[test]
    fn given_text_without_dictionary_terms_when_enforcing_then_it_is_returned_untouched() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::new("GitHub")]);
        let text = "Rien à corriger ici : ponctuation, accents… tout reste.";

        // When
        let enforced = enforce(text, &dict);

        // Then
        assert_eq!(enforced, text);
    }

    #[test]
    fn given_already_canonical_text_when_enforcing_again_then_nothing_changes() {
        // Given
        let dict = dictionary(vec![DictionaryEntry::with_aliases("GitHub", ["git hub"])]);
        let already_enforced = enforce("pousse sur git hub", &dict);
        assert_eq!(already_enforced, "pousse sur GitHub");

        // When
        let enforced_again = enforce(&already_enforced, &dict);

        // Then
        assert_eq!(enforced_again, already_enforced);
    }
}

mod at_scale {
    use super::*;

    fn five_hundred_aliased_entries() -> Vec<DictionaryEntry> {
        (0..500)
            .map(|i| {
                DictionaryEntry::with_aliases(
                    format!("Codename{i:03}"),
                    [format!("code name {i:03}")],
                )
            })
            .collect()
    }

    #[test]
    fn given_500_entries_when_enforcing_then_every_entry_is_covered_without_notable_degradation() {
        // Given
        let dict = dictionary(five_hundred_aliased_entries());
        let text = "on migre codename007 vers codename250 dès que code name 499 est prêt, \
                    puis on répartit le reste des services sur les clusters de secours \
                    avant la revue de mardi matin avec toute l'équipe plateforme et les \
                    responsables de la migration des données historiques vers le nouveau \
                    socle commun validé la semaine dernière par l'architecture";

        // When
        let started = std::time::Instant::now();
        let enforced = enforce(text, &dict);
        let elapsed = started.elapsed();

        // Then
        assert!(enforced.contains("Codename007"));
        assert!(enforced.contains("Codename250"));
        assert!(
            enforced.contains("Codename499"),
            "alias of entry #499, far beyond the boost cap"
        );
        assert!(
            elapsed < std::time::Duration::from_millis(500),
            "enforcement over 500 entries took {elapsed:?}"
        );
    }
}
