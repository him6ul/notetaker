import AVFoundation

/// Converts any incoming PCM buffer to the 16 kHz mono Float32 that Whisper expects.
/// One instance per audio source (mic / system) so converters aren't shared across formats.
final class Resampler {
    /// Whisper's required input format.
    static let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    private var converter: AVAudioConverter?
    private var lastInputFormat: AVAudioFormat?

    /// Returns 16 kHz mono float samples for `input`, or nil if conversion failed.
    func resample(_ input: AVAudioPCMBuffer) -> [Float]? {
        guard input.frameLength > 0 else { return [] }

        if converter == nil || lastInputFormat != input.format {
            converter = AVAudioConverter(from: input.format, to: Self.whisperFormat)
            converter?.sampleRateConverterQuality = .max
            lastInputFormat = input.format
        }
        guard let converter else { return nil }

        let ratio = Self.whisperFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1_024
        guard let output = AVAudioPCMBuffer(pcmFormat: Self.whisperFormat, frameCapacity: capacity) else {
            return nil
        }

        var suppliedOnce = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if suppliedOnce {
                outStatus.pointee = .noDataNow
                return nil
            }
            suppliedOnce = true
            outStatus.pointee = .haveData
            return input
        }

        guard status != .error, let channel = output.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
    }
}
