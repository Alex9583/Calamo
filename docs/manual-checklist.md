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
- Levers, env read at launch. Never exec the binary from a shell — TCC
  then attributes Accessibility to the shell and the grant is lost.
  Inject into launchd instead, e.g.
  `launchctl setenv CALAMO_FORCE_LAST_RESORT 1 && open build/Calamo.app`
  (then `launchctl unsetenv CALAMO_FORCE_LAST_RESORT` after the step):
  - `CALAMO_PASTE_BLOCKED=<id,id>` — those apps skip paste and take the
    keystroke fallback.
  - `CALAMO_FORCE_LAST_RESORT=1` — both syntheses fail: the only path to
    the last resort.
  - `CALAMO_CLEANUP_GGUF=<bad path>` — cleanup never loads: every
    dictation degrades.
  - `CALAMO_MODELS_DIR=<dir>` — the whole model store redirected: point
    it at an empty directory to walk a first install without touching
    the real one.
  - `CALAMO_ONBOARDING=1` — the wizard shows again even after it was
    completed.
- Clipboard sentinel, used throughout: `printf 'témoin' | pbcopy`,
  checked with `pbpaste`.
- Files: dictionary at
  `~/Library/Application Support/com.calamo.Calamo/dictionary.toml`,
  models at `~/Library/Application Support/com.calamo.Calamo/models`
  (SHA-256-pinned by the ModelStore; the golden suites keep their own
  copies in FluidAudio's cache).
- Steps marked *(hardware)* need a second input device or a non-Apple
  external keyboard — skip when absent.
- Rebuilding mid-pass invalidates the Accessibility grant (ad-hoc
  signature): remove Calamo from the Accessibility pane, then
  `tccutil reset Accessibility com.calamo.Calamo`, relaunch, re-grant.

## A — Hotkey: CGEventTap + Accessibility

### A1 Permission gate

1. Reset both permissions, launch.
   - [ ] The microphone and Accessibility prompts appear; **Input
     Monitoring never lists Calamo**.
2. Grant Accessibility.
   - [ ] Within ~2 s the hotkey arms — no relaunch; quill icon in the
     menu bar; once models load: « Ready — hold Fn to dictate ».

### A2 Push-to-talk

macOS decides a brief Fn press ahead of the app: unless « Press 🌐
key to » is « Do Nothing », the 🌐 action fires no matter what Calamo
swallows. The 🌐 checks below therefore run with the guidance of step 2
applied.

1. Focus TextEdit, hold Fn, say « bonjour, ceci est un premier essai »,
   release.
   - [ ] Capture runs only while held: start chime, waveform pill
     bottom-centered on the focused screen moving with your voice, end
     chime; a brief wait animation, then the pill dissolves as the text
     lands at the caret.
   - [ ] On the launch's very first dictation the pill appears as
     instantly as on the following ones (`CALAMO_TRACE=1` logs
     « pill shown — N ms after press » to compare).
   - [ ] Ordinary typing and shortcuts stay untouched between dictations.
2. Settings…, with Fn bound and System Settings → Keyboard → « Press 🌐
   key to » on its macOS default — anything but « Do Nothing ».
   - [ ] Next to the shortcut: « Apple keyboard: set « Press 🌐 key to »
     to « Do Nothing » so holding Fn only dictates. »; « Open Keyboard
     Settings » opens the Keyboard pane.
   - Pick « Do Nothing », come back to the Calamo Settings window.
   - [ ] The guidance row is gone.
3. With « Do Nothing » applied, dictate again, then tap Fn briefly.
   - [ ] The 🌐 system action (emoji picker, input switching) never
     fires — not from the hold, not from the brief press.
4. Settings… → Hold to dictate → Change…, press Fn.
   - [ ] « Press your shortcut… (Esc cancels) »; recording never starts a
     dictation.
   - [ ] The capture lands on the release; with « Do Nothing » applied,
     the 🌐 system action never fires from recording Fn.
5. Record a chord (e.g. ⌃⌥), dictate with it, rebind Fn.
   - [ ] The chord starts and ends dictations; the menu status line names
     the current binding.
   - [ ] *(hardware)* With a non-Apple external keyboard, Settings
     proposes: « External keyboard detected — ⌃⌥ needs no Fn key. »

### A3 Accessibility revoked mid-run

1. With Calamo running, switch Accessibility off in System Settings →
   Privacy & Security.
   - [ ] Within ~2 s: ⚠︎ icon, « Accessibility permission needed — Open
     System Settings », click → the Accessibility pane.
   - [ ] Within ~2 s the hotkey goes inert and **the system keyboard
     keeps working**: the tap is torn down — an orphan active tap
     survives revocation and swallows all keyboard input until re-grant.
2. Re-grant, wait for Ready; start a dictation and flip Accessibility
   off while still holding Fn.
   - [ ] Within ~2 s the hold ends on its own — end chime, the pill
     leaves; the keyboard stays alive. (The insertion may take the last
     resort: the grant is gone.)
3. Re-grant.
   - [ ] Within ~2 s dictation works again — no relaunch; menu bar back
     to « Ready — hold Fn to dictate ».

## B — Insertion: the real-app matrix

Per app: sentinel on the clipboard, focus a text area, dictate « voilà
déjà l'été, ça fonctionne », wait ≥ 1 s.

| App | Text lands, accents intact | `pbpaste` → sentinel |
|---|---|---|
| TextEdit | ☐ | ☐ |
| Safari — a web `<textarea>` | ☐ | ☐ |
| Slack — message box | ☐ | ☐ |

- [ ] Keystroke fallback, once: relaunch with
  `CALAMO_PASTE_BLOCKED=com.apple.TextEdit`, dictate into TextEdit.
  Speed does not discriminate (≤ 20-unit chunks land in a few events);
  the pasteboard does: read
  `swift -e 'import AppKit; print(NSPasteboard.general.changeCount)'`
  before and after — unchanged = keystrokes (clipboard never touched);
  a paste bumps it by 2 (write + restore). Contrast with a paste app.
  (An app that joins `PasteQuirks.standard` — none today — takes this
  path in production: walk its row without the lever.)
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
- The post-update rendition of this refusal is walked in F3.

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

### D6 Models missing or corrupted

The store repairs what it can at launch; « Models missing » only shows
when repair itself fails, so the walk cuts the network first.

1. Quit, turn Wi-Fi off, remove one weight, launch:

   ```sh
   mv "$HOME/Library/Application Support/com.calamo.Calamo/models/parakeet-tdt-0.6b-v3/Encoder.mlmodelc/weights/weight.bin"{,.aside}
   ```

   - [ ] A pulsing attempt, then ⚠︎ + « Models missing — Redownload »;
     dictation attempt → pill « Models missing ».
2. Turn Wi-Fi back on, click the status line.
   - [ ] Pulsing icon + « Loading models… (2/3) » while the weight
     redownloads (SHA-256 verified), then Ready — no relaunch. Delete
     the `.aside` copy.
3. Corrupt a model in place, relaunch:

   ```sh
   dd if=/dev/urandom conv=notrunc bs=1k count=1 \
      of="$HOME/Library/Application Support/com.calamo.Calamo/models/parakeet-tdt-0.6b-v3/Encoder.mlmodelc/weights/weight.bin"
   ```

   - [ ] The launch catches the bad hash and self-heals without a click:
     pulsing + « Loading models… (2/3) », then Ready.
4. *(download ~1.9 GB)* First install: quit, launch with
   `CALAMO_MODELS_DIR` pointing at an empty directory.
   - [ ] Pulsing + « Loading models… (0/3) » counting up to (3/3) —
     resume works: quit after (1/3), relaunch, the count reopens at
     (1/3) and nothing already installed is refetched.
   - [ ] Then the ANE compile window (still « Loading models… »), then
     Ready and a successful dictation.

### D7 Invalid dictionary TOML

1. Menu → Dictionary…
   - [ ] The file opens in the app associated with `.toml` (TextEdit if
     none) — never an app picker.
2. With Calamo running:
   `echo 'broken =' >> ~/Library/Application\ Support/com.calamo.Calamo/dictionary.toml`
   - [ ] Notification « Invalid dictionary » — « Line N: … — the previous
     dictionary stays active. » (First notice ever: macOS asks to allow
     Calamo notifications — allow. No prompt and no notification means
     the grant was silently denied — ad-hoc resigning does this: enable
     Calamo under System Settings → Notifications, retrigger.)
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

## F — Onboarding & post-update

The E checks apply here too, except that the wizard window itself is a
normal, focusable window.

### F1 First-launch wizard *(download ~1.9 GB)*

Quit; make a true first launch: reset both TCC grants per Setup,
`defaults delete com.calamo.Calamo onboardingDone`, and point
`CALAMO_MODELS_DIR` at an empty directory. Launch.

- [ ] The wizard opens on « Welcome to Calamo »: « 100% local — nothing
  ever leaves your Mac. » and the three models with exact sizes; the
  menu bar already pulses « Loading models… (0/3) » — the download
  started without a click.
- [ ] Get Started → Microphone: « Allow Microphone Access » → system
  prompt → « Microphone allowed » green check, Continue enables.
- [ ] Accessibility: « Open System Settings » opens the pane; the grant
  is auto-detected without relaunch → « Accessibility granted ».
- [ ] Apple keyboard *(skip with a non-Apple external one)*: the same
  step guides « Press 🌐 key to » → « Do Nothing », with « Open
  Keyboard Settings » opening the Keyboard pane.
- [ ] Models: « Downloading models… (n/3) » with sizes and « Downloads
  resume automatically if interrupted. », then — without a click —
  « Optimizing for your Mac… » / « One time only — about a minute. »,
  then « Models ready ».
- [ ] Try it: click the in-app field, hold Fn, say « hello everyone » —
  the cleaned text lands in the field and « Dictation works — you're
  all set. » appears. Finish closes the wizard.
- [ ] Relaunch: the wizard does not reappear.
- [ ] Gatekeeper is mentioned nowhere in the app — that story lives on
  the DMG background and the tap caveats
  ([distribution.md](distribution.md)).

### F2 Every step skippable

Reset both TCC grants, relaunch with `CALAMO_ONBOARDING=1`; click
« Later » through all five steps without granting anything.

- [ ] The wizard walks through and closes; no prompt is forced.
- [ ] The menu bar takes over: ⚠︎ + the missing permission's actionable
  line — the wizard itself is never re-proposed.

### F3 Post-update ambient recompilation

With the app having reached Ready at least once, simulate an updated
binary:

```sh
defaults write com.calamo.Calamo aneCompiledIdentity STALE
open build/Calamo.app
```

- [ ] No wizard, no notification: dimmed-pulsing icon and status line
  « Optimizing after update… (~1 min, once) » until Ready. (The
  defaults write keeps the walk offline-fast; a real `./build.sh`
  rebuild — re-grant per Setup — replays the true ~40 s compile.)
- [ ] Hold Fn during the window → pill « Optimizing after update…
  (~1 min, once) ».
- [ ] Once Ready, quit and relaunch → ordinary « Loading models… »; the
  post-update label does not reappear.
