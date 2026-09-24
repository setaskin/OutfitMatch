//
//  SpeechRecognizer.swift
//  OutfitMatch
//
//  Voice-to-text for the chat input: tap the mic, speak, the transcript
//  streams into the text field live. Uses Apple's on-device Speech
//  framework — no network call, no API key, and it's the user's own device
//  doing the transcription.

import Combine
import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    /// Set in hands-free mode: called with the finished utterance once the
    /// user has stopped talking, so the conversation can continue without a
    /// tap. Left nil for the plain dictate-into-the-field case.
    var onUtteranceEnd: ((String) -> Void)?
    /// How long a pause counts as "done talking". Long enough to think
    /// mid-sentence, short enough not to feel unresponsive.
    private let silenceThreshold: TimeInterval = 1.6

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastTranscriptChange = Date()

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        errorMessage = nil
        transcript = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                guard let self else { return }
                guard authStatus == .authorized else {
                    self.errorMessage = "Speech recognition permission denied. Enable it in Settings."
                    return
                }
                self.requestMicPermission()
            }
        }
    }

    private func requestMicPermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.errorMessage = "Microphone permission denied. Enable it in Settings."
                    return
                }
                self.beginTranscribing()
            }
        }
    }

    private func beginTranscribing() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't start the audio session."
            return
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "Couldn't start recording."
            return
        }

        audioEngine = engine
        self.request = request
        isRecording = true

        lastTranscriptChange = Date()
        startSilenceTimerIfNeeded()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let updated = result.bestTranscription.formattedString
                    if updated != self.transcript {
                        self.transcript = updated
                        self.lastTranscriptChange = Date()
                    }
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.finishUtterance()
                }
            }
        }
    }

    /// Hands-free mode ends an utterance on a pause; tap-to-dictate waits for
    /// the user to tap again, so the timer only runs when it's needed.
    private func startSilenceTimerIfNeeded() {
        guard onUtteranceEnd != nil else { return }
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                guard !self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                if Date().timeIntervalSince(self.lastTranscriptChange) >= self.silenceThreshold {
                    self.finishUtterance()
                }
            }
        }
    }

    private func finishUtterance() {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let handler = onUtteranceEnd
        stopRecording()
        if !spoken.isEmpty { handler?(spoken) }
    }

    func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        audioEngine = nil
        request = nil
        task = nil
        isRecording = false
    }

    /// Start a fresh listen without clearing `onUtteranceEnd`, for the next
    /// turn of a hands-free conversation.
    func listenAgain() {
        guard !isRecording else { return }
        startRecording()
    }
}
