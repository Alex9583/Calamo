//! The dictionary.toml `DictionaryRepository`: the user edits a plain file,
//! the engine hot-reloads it. Missing file → recreated from the template, so
//! the first launch and a deleted file both self-heal on the next load.

mod parse;

use std::fs;
use std::io::ErrorKind;
use std::path::PathBuf;

use calamo_core::dictionary::Dictionary;
use calamo_core::ports::{DictionaryLoadError, DictionaryRepository};

/// User-facing artefact: header in English like the rest of the UI, live
/// example entries.
const TEMPLATE: &str = r#"# Calamo dictionary — your enforced spellings.
#
# One entry per line: text is the exact spelling to insert, aliases
# (optional) the pronunciations that should lead to it.
# Entry order is priority: the first one wins.
# Save the file: Calamo reloads the dictionary at once, no restart needed.

entries = [
    { text = "GitHub", aliases = ["github", "git hub"] },
    { text = "PR", aliases = ["péère"] },
    { text = "Calamo" },
]
"#;

pub struct TomlDictionaryRepository {
    path: PathBuf,
}

impl TomlDictionaryRepository {
    pub fn at(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    fn read_or_create(&self) -> Result<String, DictionaryLoadError> {
        match fs::read_to_string(&self.path) {
            Ok(content) => Ok(content),
            Err(error) if error.kind() == ErrorKind::NotFound => self
                .create_template()
                .map(|()| TEMPLATE.to_string())
                .map_err(|error| self.io_error(&error)),
            Err(error) => Err(self.io_error(&error)),
        }
    }

    fn create_template(&self) -> std::io::Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&self.path, TEMPLATE)
    }

    fn io_error(&self, error: &std::io::Error) -> DictionaryLoadError {
        DictionaryLoadError {
            line: None,
            message: format!("{}: {error}", self.path.display()),
        }
    }
}

impl DictionaryRepository for TomlDictionaryRepository {
    fn load(&self) -> Result<Dictionary, DictionaryLoadError> {
        parse::parse(&self.read_or_create()?)
    }
}
