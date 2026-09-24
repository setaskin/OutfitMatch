//
//  SpeechSynthesizer.swift
//  OutfitMatch
//
//  Speaks Claude's replies aloud, so the chat can be held hands-free rather
//  than read. Uses Apple's on-device AVSpeechSynthesizer — no API call, no
//  cost, works offline, and nothing leaves the device to produce the audio.

import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechSynthesizer: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published var errorMessage: String?

    private let synthesizer = AVSpeechSynthesizer()
    /// Called when speech finishes or is cancelled, so the caller can decide
    /// what happens next — in a hands-free loop, that's resuming listening.
    private var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, onFinish: (() -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onFinish?()
            return
        }

        self.onFinish = onFinish

        // The session is already configured for both directions, so there's
        // no category to swap here. Just make sure it's active — if it isn't,
        // report it instead of failing silently, which previously looked like
        // the reply had simply vanished.
        do {
            try AudioSessionConfig.activateForConversation()
        } catch {
            errorMessage = "Couldn't play audio — check the silent switch and volume."
            self.onFinish = nil
            onFinish?()
            return
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.1

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        onFinish = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension SpeechSynthesizer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            let callback = self.onFinish
            self.onFinish = nil
            callback?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.onFinish = nil
        }
    }
}
