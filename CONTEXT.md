# Calamo

Local-only voice dictation for macOS: hold a hotkey, speak, release — the cleaned-up text is inserted at the cursor.

## Language

**Dictation**:
One complete push-to-talk interaction, from hotkey press to text insertion. The aggregate root: it moves through Capturing → Transcribing → Cleaning → Inserting → Completed or Failed.
_Avoid_: Session, recording, dictation session

**Utterance**:
The audio segment captured during one Dictation, between hotkey press and release. The unit on which language auto-detection operates.
_Avoid_: Audio clip, recording, speech segment

**RawTranscript**:
The text produced by speech recognition from an Utterance, before any cleanup.
_Avoid_: Transcription, ASR output

**CleanedText**:
The final text ready for insertion: hesitations and self-corrections rewritten, dictionary spellings enforced.
_Avoid_: Clean text, output text, final text

**Dictionary**:
The user's ordered list of DictionaryEntries. Order is priority; canonical texts are unique. The single artefact behind ASR boosting, the prompt glossary, and spelling enforcement.
_Avoid_: Custom vocabulary, word list, lexicon

**DictionaryEntry**:
One enforced spelling with its spoken aliases (e.g. "GitHub" with aliases "github", "git hub").
_Avoid_: Word, term, hotword

**Boost List**:
The derived view of the Dictionary (first ~100 entries) handed to speech recognition for contextual biasing.
_Avoid_: Custom vocabulary, hotwords

**Prompt Glossary**:
The derived view of the Dictionary (≤50 entries, or a fuzzy-matched subset) injected into the cleanup prompt. "Glossary" never means the Dictionary itself.
_Avoid_: Glossary (for the user artefact)

**Spelling Enforcement**:
The deterministic domain service that applies Dictionary spellings to CleanedText — the only stage that guarantees a spelling.
_Avoid_: Fuzzy correction, post-processing

**Engine**:
The runtime hosting the pipeline. Its state (Loading → Ready | Unavailable) gates dictation: no Dictation is born outside Ready — a hotkey press then yields a refusal event carrying its cause.
_Avoid_: Session, service

**Degraded Dictation**:
A Dictation completed by inserting the RawTranscript (spellings still enforced) because cleanup failed. Degraded is still Completed, never Failed.
_Avoid_: Fallback, partial dictation
