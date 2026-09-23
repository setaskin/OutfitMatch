//
//  ChatComponents.swift
//  OutfitMatch
//
//  Chat pieces shared between the conversation screen and the results
//  screen, since results are refinable in place — the user can keep talking
//  ("make it black", "cheaper") without going back.

import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.scanMint : Color.scanSurface)
                .foregroundStyle(message.role == .user ? Color.scanBackground : Color.scanInk)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

/// Mic + text field + send, used by both chat surfaces.
struct ChatInputBar: View {
    @Binding var text: String
    @ObservedObject var speechRecognizer: SpeechRecognizer
    var placeholder: String
    var isSending: Bool
    var onSend: () -> Void

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                speechRecognizer.toggleRecording()
            } label: {
                Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundStyle(speechRecognizer.isRecording ? Color.scanAmber : Color.scanMint)
                    .frame(width: 34, height: 34)
            }
            .disabled(isSending)
            .accessibilityLabel(speechRecognizer.isRecording ? "Stop voice input" : "Start voice input")

            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.scanInk)
                .tint(Color.scanMint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundStyle(Color.scanInkDim)
                }
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.scanSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(trimmed.isEmpty ? Color.scanInkDim : Color.scanMint)
            }
            .disabled(trimmed.isEmpty || isSending)
            .accessibilityLabel("Send")
        }
        .padding()
    }
}

extension View {
    /// SwiftUI has no styleable placeholder, and an empty TextField collapses
    /// to a near-zero tap target, so the field is overlaid rather than swapped.
    @ViewBuilder
    func placeholder(when shouldShow: Bool, @ViewBuilder placeholder: () -> some View) -> some View {
        ZStack(alignment: .topLeading) {
            if shouldShow { placeholder().allowsHitTesting(false) }
            self
        }
        .contentShape(Rectangle())
    }
}
