# Manual release checklist

The OS glue no harness can drive — event tap, TCC, real apps, real
microphones — walked step by step on a real machine. Run a full pass
before merging a release PR; rerun the touched section after any change
to input, capture, insertion, or feedback. Nothing is archived: a
deviation gets a ticket or a fix before merge.

The contract is the UX spec's error policy: **overlay = events, menu bar
= persistent state, notification = action required.** Expected copy is
quoted exactly — a paraphrased label is a deviation.

## Setup

```sh
./build.sh && open build/Calamo.app
```

- Start clean:
  `tccutil reset Accessibility com.calamo.Calamo && tccutil reset Microphone com.calamo.Calamo`
- Levers, env read at launch — run the bundled binary directly, e.g.
  `CALAMO_FORCE_LAST_RESORT=1 build/Calamo.app/Contents/MacOS/Calamo`:
  - `CALAMO_PASTE_BLOCKED=<id,id>` — those apps skip paste and take the
    keystroke fallback.
  - `CALAMO_FORCE_LAST_RESORT=1` — both syntheses fail: the only path to
    the last resort.
  - `CALAMO_CLEANUP_GGUF=<bad path>` — cleanup never loads: every
    dictation degrades.
- Clipboard sentinel, used throughout: `printf 'témoin' | pbcopy`,
  checked with `pbpaste`.
- Files: dictionary at
  `~/Library/Application Support/com.calamo.Calamo/dictionary.toml`, ASR
  models at `~/Library/Application Support/FluidAudio/Models`.
- Steps marked *(hardware)* need a second input device or a non-Apple
  external keyboard — skip when absent.

## A — Hotkey: CGEventTap + Accessibility

### A1 Permission gate

1. Reset both permissions, launch.
   - [ ] The microphone and Accessibility prompts appear; **Input
     Monitoring never lists Calamo**.
2. Grant Accessibility, relaunch (v1 creates the tap at launch).
   - [ ] Quill icon in the menu bar; once models load:
     « Ready — hold Fn to dictate ».

### A2 Push-to-talk

1. Focus TextEdit, hold Fn, say « bonjour, ceci est un premier essai »,
   release.
   - [ ] Capture runs only while held: start chime, waveform pill
     bottom-centered on the focused screen moving with your voice, end
     chime; a brief wait animation, then the pill dissolves as the text
     lands at the caret.
   - [ ] The 🌐 system action (emoji picker, input switching) never fires
     from the hold.
   - [ ] Ordinary typing and shortcuts stay untouched between dictations.
2. Settings… → Hold to dictate → Change…, press Fn.
   - [ ] « Press your shortcut… (Esc cancels) »; recording never starts a
     dictation.
3. Record a chord (e.g. ⌃⌥), dictate with it, rebind Fn.
   - [ ] The chord starts and ends dictations; the menu status line names
     the current binding.
   - [ ] *(hardware)* With a non-Apple external keyboard, Settings
     proposes: « External keyboard detected — ⌃⌥ needs no Fn key. »

### A3 Accessibility revoked mid-run

1. With Calamo running, switch Accessibility off in System Settings →
   Privacy & Security.
   - [ ] Within ~2 s: ⚠︎ icon, « Accessibility permission needed — Open
     System Settings », click → the Accessibility pane.
   - [ ] The hotkey is inert while revoked — the tap is dead, the refusal
     surfaces on the menu bar, not the overlay.
2. Re-grant, relaunch — v1 never recreates a dead tap; automatic grant
   detection arrives with onboarding (ticket 20).
   - [ ] Ready again; dictation works.

## B — Insertion: the real-app matrix

Per app: sentinel on the clipboard, focus a text area, dictate « voilà
déjà l'été, ça fonctionne », wait ≥ 1 s.

| App | Text lands, accents intact | `pbpaste` → sentinel |
|---|---|---|
| TextEdit | ☐ | ☐ |
| Safari — a web `<textarea>` | ☐ | ☐ |
| Slack — message box | ☐ | ☐ |

- [ ] Keystroke fallback, once: relaunch with
  `CALAMO_PASTE_BLOCKED=com.apple.TextEdit`, dictate into TextEdit — the
  text arrives as keystrokes (visibly slower), the sentinel never
  touched. (An app that joins `PasteQuirks.standard` — none today — takes
  this path in production: walk its row without the lever.)
- [ ] If a clipboard manager runs: the dictated text never enters its
  history.
- [ ] An app that silently swallows the paste is a deviation: its bundle
  ID goes into `PasteQuirks.standard`.

### B2 Secure fields

1. Web password field:

   ```sh
   printf '<input type="password" autofocus>' > /tmp/calamo-password.html
   open -a Safari /tmp/calamo-password.html
   ```

   Focus the field, attempt a dictation.
   - [ ] Nothing lands in the field; sentinel intact. Either the pill
     shows « Secure field — dictation refused », or Safari holds secure
     input and mutes the hotkey — padlock badge instead.
2. Terminal → Secure Keyboard Entry, on.
   - [ ] Within ~2 s: padlock badge, « Secure input active — dictation
     muted ».
   - [ ] A dictation attempt inserts nothing; a chord that survives the
     muting ends in « Secure field — dictation refused ».
   - [ ] Off → Ready returns within ~2 s.

## C — Capture: AVAudioEngine glue *(hardware)*

1. Settings… → Input device: pick a second microphone.
   - [ ] The waveform follows it — cover it and the wave flattens even
     while speaking near the built-in one; text lands.
2. Back to « System default »: change the system input device.
   - [ ] The next dictation follows the new default, no relaunch.
3. Pin the second mic, unplug it while idle.
   - [ ] Settings shows « … (not connected) » plus « Not connected — the
     system default microphone is used. »; dictation succeeds on the
     default.
4. Pin it again, dictate on it, unplug mid-hold, release.
   - [ ] No crash; the dictation ends in a prescribed surface — text from
     the audio captured so far, « Nothing heard », or « Microphone
     unavailable » — never silence, never garbage.
   - [ ] The next dictation succeeds on the system default.

## D — Error policy, case by case

Each case produces exactly its prescribed feedback and nothing more — no
notification unless stated.

### D1 Empty dictation

Hold Fn in silence ~2 s, release.

- [ ] Pill « Nothing heard », brief; nothing inserted.

### D2 Secure field

Covered in [B2](#b2-secure-fields) — tick there.

### D3 Engine not ready

Quit, relaunch, hold Fn during the loading window (the first seconds).

- [ ] Pill « Models loading… »; menu bar dimmed-pulsing icon +
  « Loading models… ».
- Dictate a long phrase, release, immediately hold again.
  - [ ] Pill « Still processing… », then the wait animation resumes for
    the dictation still in flight.
- The post-update rendition (« Optimisation après mise à jour… ») lands
  with ticket 20 and joins this case then.

### D4 Cleanup failed → degraded dictation

Relaunch with `CALAMO_CLEANUP_GGUF=/nonexistent`; dictate « euh donc
voilà en fait le truc quoi ».

- [ ] The verbatim transcript lands, hesitations kept; pill « Inserted
  without cleanup » ~1 s. Degraded is Completed: no ⚠︎, no notification.
- [ ] A dictated dictionary alias still lands as its canonical spelling.

### D5 Microphone permission revoked

System Settings → Privacy & Security → Microphone: switch Calamo off.
Use the toggle, not `tccutil reset` — reset returns to not-determined,
which reads as still-pending, not revoked. Relaunch if macOS quits the
app.

- [ ] Within ~2 s: ⚠︎ + « Microphone permission needed — Open System
  Settings », click → the Microphone pane.
- [ ] Dictation attempt → pill « Microphone access revoked »; nothing
  inserted.

### D6 Models missing

Quit, then launch after:

```sh
mv "$HOME/Library/Application Support/FluidAudio/Models" \
   "$HOME/Library/Application Support/FluidAudio/Models.aside"
```

- [ ] ⚠︎ + « Models missing — Redownload »; dictation attempt → pill
  « Models missing ».
- Restore the directory, click the status line.
  - [ ] Loading, then Ready — the click retries the load; the real
    download and the corrupted-model path (pinned SHA-256) land with the
    ModelStore (ticket 19).

### D7 Invalid dictionary TOML

1. Menu → Dictionary…
   - [ ] The file opens in the app associated with `.toml` (TextEdit if
     none) — never an app picker.
2. With Calamo running:
   `echo 'broken =' >> ~/Library/Application\ Support/com.calamo.Calamo/dictionary.toml`
   - [ ] Notification « Invalid dictionary » — « Line N: … — the previous
     dictionary stays active. » (First notice ever: macOS asks to allow
     Calamo notifications — allow.)
   - [ ] An alias still lands as its canonical spelling.
3. Remove the line, save.
   - [ ] Hot reload, silent, no restart.

### D8 Total insertion failure

Relaunch with `CALAMO_FORCE_LAST_RESORT=1`; sentinel on the clipboard;
dictate « texte de dernier recours » into TextEdit.

- [ ] Nothing inserted; pill « Insertion failed »; notification
  « Insertion failed » — « Text copied — paste with ⌘V ».
- [ ] `pbpaste` → the dictated text, plain, never restored over; ⌘V
  pastes it.
- [ ] Dictate again: the pending notification is replaced, never stacked.

## E — Cross-cutting

- [ ] **Focus is never stolen.** Across every step: the frontmost app
  never changes, the caret never moves, the pill takes no clicks and
  floats over full-screen apps; with a second display, it sits on the
  screen holding keyboard focus.
- [ ] **The clipboard always comes back.** The sentinel survives every
  path except D8's last resort.
- [ ] **No notification without a required action.** Over the whole pass,
  exactly two cases notified: D7 and D8.
- [ ] **Sounds.** Chimes at start and end by default; Settings toggle off
  → silent dictations; on → chimes return.
