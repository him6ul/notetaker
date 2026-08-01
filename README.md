# NoteTaker

A native macOS menu-bar app that listens to a conversation — **you and the other
people**, including the far side of a video call — transcribes it locally, extracts
**ideas** and **action items**, and emails the whole package (transcript + ideas +
action items) to your inbox.

Everything runs **on-device**. The only thing that leaves your Mac is the final email.

| Stage | Technology |
|---|---|
| Your voice | Microphone via `AVAudioEngine` |
| Other people / call audio | System audio via **ScreenCaptureKit** (no BlackHole needed) |
| Transcription | **WhisperKit** (local CoreML Whisper, runs on the Neural Engine) |
| Ideas & action items | **Ollama** running a local LLM (`llama3.1:8b` by default) |
| Delivery | **Gmail SMTP** via `curl` (App Password) |

---

## One-time setup

### 1. Ollama (the ideas / action-item engine)

```bash
brew install ollama
ollama serve            # leave running (or use the Ollama.app)
ollama pull llama3.1:8b
```

### 2. Gmail App Password (so the app can send email)

You must do this yourself — it needs 2-Step Verification on the sending Google account:

1. Google Account → **Security** → **2-Step Verification** (turn on if needed)
2. **App passwords** → generate one for "Mail"
3. Launch NoteTaker → **Settings…** → paste it into **Gmail App Password** → **Save Password**
   (stored in your macOS Keychain, never in a file)

Default recipient and sender are both `him6ul@gmail.com` (send-to-self); change either
in Settings.

### 3. First launch permissions

On first **Start Listening**, macOS will prompt for:
- **Microphone** — allow it.
- **Screen Recording** — allow it (ScreenCaptureKit needs this to capture system audio;
  no video is recorded — the app requests a 2×2 dummy frame it discards).

WhisperKit downloads the Whisper model automatically on first run (~150 MB for `base.en`).

---

## Build & run

```bash
brew install xcodegen           # if not already installed
xcodegen generate               # produces NoteTaker.xcodeproj
open NoteTaker.xcodeproj         # then press Run
```

Or from the command line:

```bash
xcodebuild -project NoteTaker.xcodeproj -scheme NoteTaker \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build build
open build/Build/Products/Debug/NoteTaker.app
```

A waveform icon appears in the menu bar. **Start Listening** → have your conversation →
**Stop & Review Notes**. An editable **Review** window then opens showing the summary,
ideas, action items, and full transcript — tweak anything you like, then click **Send
Notes** (or **Discard**). Nothing is emailed until you press Send. A notification
confirms when the email is on its way.

---

## How it works

```
 Mic (AVAudioEngine) ───┐
                        ├─► resample to 16 kHz mono ─► WhisperKit ─► labeled segments
 System audio (SCKit) ──┘        (every ~8 s, per source)   │  "Me:" / "Others:"
                                                            ▼
                                              TranscriptStore (merged transcript)
                                                            │ (on Stop)
                                                            ▼
                                              Ollama /api/chat  → { summary, ideas,
                                                            │        action_items }
                                                            ▼
                                              Editable Review window (edit / Send / Discard)
                                                            │ (on Send)
                                                            ▼
                                              curl → smtps://smtp.gmail.com → your inbox
```

The two audio sources are transcribed **separately** so the transcript can label who
spoke — **Me** (your mic) vs **Others** (system audio).

---

## Settings reference

| Field | Default | Notes |
|---|---|---|
| Send notes to | `him6ul@gmail.com` | recipient |
| From (Gmail account) | `him6ul@gmail.com` | must match the App Password's account |
| Gmail App Password | — | stored in Keychain |
| Whisper model | `openai_whisper-base.en` | try `openai_whisper-small.en` for accuracy |
| Ollama model | `llama3.1:8b` | any model you've `ollama pull`ed |

---

## Troubleshooting

- **"Couldn't reach Ollama"** — run `ollama serve` and confirm the model is pulled
  (`ollama list`).
- **Email fails** — verify the App Password (no spaces needed) and that the sender
  account matches. Gmail SMTP uses `smtps://smtp.gmail.com:465`.
- **No "Others:" lines** — grant **Screen Recording** in System Settings → Privacy &
  Security, then restart the app.
- **Nothing transcribed** — speak clearly for a few seconds; chunks under ~0.5 s of
  audio are skipped as silence.

---

## Project layout

```
NoteTaker/
  NoteTakerApp.swift          # menu-bar UI (MenuBarExtra)
  SettingsView.swift          # settings window
  AppState.swift              # orchestration: capture → transcribe → summarize → email
  Audio/                      # MicCapture, SystemAudioCapture, Resampler
  Transcription/              # Transcriber (WhisperKit), TranscriptStore
  Analysis/Summarizer.swift   # Ollama structured-output client
  Review/                     # ReviewModel + ReviewView (editable pre-send window)
  Delivery/Mailer.swift       # curl SMTP sender
  Config/                     # AppSettings (UserDefaults), Keychain
```
