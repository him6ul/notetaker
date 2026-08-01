import AVFoundation

/// Captures the microphone via AVAudioEngine and emits 16 kHz mono float samples.
final class MicCapture {
    private let engine = AVAudioEngine()
    private let resampler = Resampler()
    private var onSamples: (([Float]) -> Void)?

    /// Asks for microphone permission. Calls back on the main thread.
    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    /// Starts tapping the mic. `onSamples` receives 16 kHz mono chunks as they arrive.
    func start(onSamples: @escaping ([Float]) -> Void) throws {
        self.onSamples = onSamples
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
            guard let self, let samples = self.resampler.resample(buffer), !samples.isEmpty else { return }
            self.onSamples?(samples)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        onSamples = nil
    }
}
