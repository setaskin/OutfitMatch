//
//  AudioSessionConfig.swift
//  OutfitMatch
//
//  One audio session configuration shared by listening and speaking.
//
//  Previously each side set its own category — `.record` to listen,
//  `.playback` to speak — which meant flipping the category mid-conversation
//  on every turn. Changing category on an active session can throw, and when
//  it did the reply was silently dropped: no speech, no error, listening just
//  resumed. `.playAndRecord` supports both directions at once, so nothing has
//  to be swapped between turns. `.voiceChat` mode also brings echo
//  cancellation, which matters when the mic reopens right after the speaker.

import AVFoundation

enum AudioSessionConfig {
    static func activateForConversation() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
