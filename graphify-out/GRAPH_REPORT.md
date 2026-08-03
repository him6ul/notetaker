# Graph Report - .  (2026-08-03)

## Corpus Check
- Corpus is ~5,047 words - fits in a single context window. You may not need a graph.

## Summary
- 191 nodes · 336 edges · 11 communities
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 35 edges (avg confidence: 0.81)
- Token cost: 24,000 input · 3,893 output

## Community Hubs (Navigation)
- App State Orchestration
- Audio Capture & Resampling
- Settings & Keychain Config
- Summarization & Email Delivery
- SwiftUI Views & App Entry
- Project Architecture Concepts
- Transcript Store & Speakers
- WhisperKit Transcription
- App Phase States
- Window Lifecycle Delegate
- Graphify Workflow

## God Nodes (most connected - your core abstractions)
1. `AppState` - 39 edges
2. `SystemAudioCapture` - 13 edges
3. `ReviewModel` - 11 edges
4. `AppSettings` - 10 edges
5. `Transcriber` - 10 edges
6. `Phase` - 9 edges
7. `MicCapture` - 9 edges
8. `TranscriptStore` - 9 edges
9. `WindowCloseDelegate` - 8 edges
10. `Mailer` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Ollama Summarizer (structured output)` --conceptually_related_to--> `Summarizer`  [INFERRED]
  README.md → NoteTaker/Analysis/Summarizer.swift
- `AppState Orchestration` --conceptually_related_to--> `AppState`  [INFERRED]
  README.md → NoteTaker/AppState.swift
- `Microphone Capture (AVAudioEngine)` --conceptually_related_to--> `MicCapture`  [INFERRED]
  README.md → NoteTaker/Audio/MicCapture.swift
- `16 kHz Mono Resampler` --conceptually_related_to--> `Resampler`  [INFERRED]
  README.md → NoteTaker/Audio/Resampler.swift
- `System Audio Capture (ScreenCaptureKit)` --conceptually_related_to--> `SystemAudioCapture`  [INFERRED]
  README.md → NoteTaker/Audio/SystemAudioCapture.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Capture to Email Pipeline** — readme_miccapture, readme_system_audio_capture, readme_resampler, readme_whisperkit, readme_transcriptstore, readme_ollama_summarizer, readme_review_window, readme_mailer [EXTRACTED 0.85]
- **Dual-Source Speaker Labeling** — readme_miccapture, readme_system_audio_capture, readme_speaker_labeling, readme_transcriptstore [INFERRED 0.85]

## Communities (11 total, 0 thin omitted)

### Community 0 - "App State Orchestration"
Cohesion: 0.13
Nodes (14): AppState, .isBusy, .isError, .isListening, Bool, String, .body, ReviewModel (+6 more)

### Community 1 - "Audio Capture & Resampling"
Cohesion: 0.10
Nodes (19): AVAudioConverter, AVAudioFormat, AVFoundation, CMSampleBuffer, MicCapture, Bool, Float, Void (+11 more)

### Community 2 - "Settings & Keychain Config"
Cohesion: 0.11
Nodes (15): AppKit, Combine, Foundation, Keychain, String, AppSettings, .appPassword, .ollamaModel (+7 more)

### Community 3 - "Summarization & Email Delivery"
Cohesion: 0.15
Nodes (18): Codable, LocalizedError, ActionItem, MeetingNotes, Summarizer, SummarizerError, badResponse, .errorDescription (+10 more)

### Community 4 - "SwiftUI Views & App Entry"
Cohesion: 0.14
Nodes (15): App, Binding, CGFloat, MenuContent, NoteTakerApp, .body, ReviewView, .body (+7 more)

### Community 5 - "Project Architecture Concepts"
Cohesion: 0.17
Nodes (17): App Entitlements (audio-input, network.client), NoteTaker XcodeGen Project, WhisperKit Swift Package Dependency, AppSettings & Keychain, AppState Orchestration, Gmail SMTP Mailer (curl), Menu-Bar UI (MenuBarExtra), Microphone Capture (AVAudioEngine) (+9 more)

### Community 6 - "Transcript Store & Speakers"
Cohesion: 0.24
Nodes (10): Identifiable, Int, Speaker, me, others, Date, TranscriptSegment, TranscriptStore (+2 more)

### Community 7 - "WhisperKit Transcription"
Cohesion: 0.25
Nodes (7): SourceBuffer, Date, Float, Float, String, Transcriber, WhisperKit

### Community 8 - "App Phase States"
Cohesion: 0.25
Nodes (8): Equatable, Phase, error, idle, listening, preparing, processing, reviewing

### Community 9 - "Window Lifecycle Delegate"
Cohesion: 0.33
Nodes (5): Void, WindowCloseDelegate, Notification, NSObject, NSWindowDelegate

### Community 10 - "Graphify Workflow"
Cohesion: 0.67
Nodes (3): Graphify Knowledge Graph Workflow, graphify query, graphify update (AST-only)

## Knowledge Gaps
- **29 isolated node(s):** `ollamaUnreachable`, `.errorDescription`, `UserNotifications`, `AppKit`, `idle` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppState` connect `App State Orchestration` to `Audio Capture & Resampling`, `Settings & Keychain Config`, `SwiftUI Views & App Entry`, `Project Architecture Concepts`, `Transcript Store & Speakers`, `WhisperKit Transcription`, `App Phase States`, `Window Lifecycle Delegate`?**
  _High betweenness centrality (0.654) - this node is a cross-community bridge._
- **Why does `SystemAudioCapture` connect `Audio Capture & Resampling` to `App State Orchestration`, `Window Lifecycle Delegate`, `Project Architecture Concepts`?**
  _High betweenness centrality (0.168) - this node is a cross-community bridge._
- **Why does `AppSettings` connect `Settings & Keychain Config` to `SwiftUI Views & App Entry`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `AppState` (e.g. with `MicCapture` and `SystemAudioCapture`) actually correct?**
  _`AppState` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `SystemAudioCapture` (e.g. with `AppState` and `Resampler`) actually correct?**
  _`SystemAudioCapture` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ollamaUnreachable`, `.errorDescription`, `UserNotifications` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `App State Orchestration` be split into smaller, more focused modules?**
  _Cohesion score 0.13068181818181818 - nodes in this community are weakly interconnected._