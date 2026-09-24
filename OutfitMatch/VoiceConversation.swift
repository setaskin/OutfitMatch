//
//  VoiceConversation.swift
//  OutfitMatch
//
//  Hands-free voice mode: speak, the reply is spoken back, and listening
//  resumes automatically — no tapping between turns.
//
//  The loop is listen → (pause detected) → send → speak → listen. Listening
//  is fully stopped before speaking rather than run concurrently, which is
//  what keeps the mic from transcribing the app's own voice back into the
//  conversation.

import AVFoundation
import Combine
import Foundation

@MainActor
final class VoiceConversation: ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case speaking
    }

    @Published private(set) var phase: Phase = .idle
    /// What the user is saying right now, shown live so they can see they're
    /// being heard.
    @Published private(set) var liveTranscript = ""
    @Published var errorMessage: String?

    /// Owns its own recognizer rather than sharing the one behind the mic
    /// button — voice mode is a separate session with different end-of-turn
    /// behaviour, and mixing the two states gets confusing fast.
    let recognizer = SpeechRecognizer()
    private let synthesizer = SpeechSynthesizer()
    /// Performs the actual send and returns the reply to speak. Supplied at
    /// start so this works for any screen without knowing anything about it.
    private var send: ((String) async -> String?)?

    private var cancellables = Set<AnyCancellable>()

    var isActive: Bool { phase != .idle }

    init() {
        recognizer.$transcript
            .sink { [weak self] text in
                guard let self, self.isActive else { return }
                self.liveTranscript = text
            }
            .store(in: &cancellables)
    }

    func start(send: @escaping (String) async -> String?) {
        guard phase == .idle else { return }
        self.send = send
        errorMessage = nil
        liveTranscript = ""

        recognizer.onUtteranceEnd = { [weak self] spoken in
            self?.handle(spoken)
        }

        phase = .listening
        recognizer.listenAgain()
    }

    func stop() {
        phase = .idle
        liveTranscript = ""
        send = nil
        recognizer.onUtteranceEnd = nil
        recognizer.stopRecording()
        synthesizer.stop()
        deactivateAudioSession()
    }

    private func handle(_ spoken: String) {
        guard isActive else { return }
        phase = .thinking
        liveTranscript = spoken

        Task {
            let reply = await send?(spoken)

            guard isActive else { return }
            guard let reply = reply ?? nil, !reply.isEmpty else {
                // Nothing to say back — carry on listening rather than
                // stranding the user in a dead mode.
                resumeListening()
                return
            }

            phase = .speaking
            synthesizer.speak(reply) { [weak self] in
                self?.resumeListening()
            }
        }
    }

    private func resumeListening() {
        guard isActive else { return }
        liveTranscript = ""
        phase = .listening
        recognizer.listenAgain()
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
