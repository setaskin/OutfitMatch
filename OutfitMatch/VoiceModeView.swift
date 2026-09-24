//
//  VoiceModeView.swift
//  OutfitMatch
//
//  The hands-free overlay: what the app is doing right now, what it heard,
//  and one obvious way out. Deliberately sparse — if you're using this,
//  you're probably not looking at the screen.

import SwiftUI

struct VoiceModeView: View {
    @ObservedObject var conversation: VoiceConversation
    var onClose: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.scanBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                orb

                Text(statusText)
                    .font(ScanFont.display(20, weight: .semibold))
                    .foregroundStyle(Color.scanInk)

                Text(conversation.liveTranscript.isEmpty ? hint : conversation.liveTranscript)
                    .font(.body)
                    .foregroundStyle(Color.scanInkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(minHeight: 60, alignment: .top)

                if let error = conversation.errorMessage ?? conversation.recognizer.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.scanAmber)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button(action: onClose) {
                    Text("Done")
                        .font(ScanFont.display(15, weight: .bold))
                        .foregroundStyle(Color.scanBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.scanMint)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear { pulse = true }
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(orbColor.opacity(0.18))
                .frame(width: 180, height: 180)
                .scaleEffect(pulse && conversation.phase == .listening ? 1.12 : 1)
                .animation(
                    conversation.phase == .listening
                        ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )

            Circle()
                .fill(orbColor.opacity(0.35))
                .frame(width: 120, height: 120)

            Image(systemName: orbIcon)
                .font(.system(size: 40))
                .foregroundStyle(Color.scanBackground)
                .frame(width: 88, height: 88)
                .background(orbColor)
                .clipShape(Circle())
        }
        .accessibilityHidden(true)
    }

    private var orbColor: Color {
        switch conversation.phase {
        case .listening: return .scanMint
        case .thinking: return .scanInkDim
        case .speaking: return .scanAmber
        case .idle: return .scanInkDim
        }
    }

    private var orbIcon: String {
        switch conversation.phase {
        case .listening: return "mic.fill"
        case .thinking: return "ellipsis"
        case .speaking: return "waveform"
        case .idle: return "mic.slash.fill"
        }
    }

    private var statusText: String {
        switch conversation.phase {
        case .listening: return "Listening…"
        case .thinking: return "Thinking…"
        case .speaking: return "Speaking…"
        case .idle: return "Voice mode off"
        }
    }

    private var hint: String {
        switch conversation.phase {
        case .listening: return "Say what you're looking for — just pause when you're done."
        case .thinking: return ""
        case .speaking: return ""
        case .idle: return ""
        }
    }
}
