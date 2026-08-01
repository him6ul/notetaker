import Foundation
import WhisperKit

/// Wraps WhisperKit for fully-local transcription. An actor so the two audio sources
/// (mic + system) never run the model concurrently — calls are naturally serialized.
actor Transcriber {
    private var whisperKit: WhisperKit?
    private let modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }

    /// Downloads (first run) and loads the CoreML Whisper model.
    func prepare() async throws {
        guard whisperKit == nil else { return }
        let config = WhisperKitConfig(model: modelName, load: true, download: true)
        whisperKit = try await WhisperKit(config)
    }

    /// Transcribes one chunk of 16 kHz mono samples. Returns joined text ("" if silence).
    func transcribe(_ samples: [Float]) async throws -> String {
        guard let whisperKit else { return "" }
        // Skip near-silent chunks so we don't waste cycles or hallucinate on noise.
        guard samples.count >= 16_000 / 2 else { return "" }

        let options = DecodingOptions(
            task: .transcribe,
            temperature: 0,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        return results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
