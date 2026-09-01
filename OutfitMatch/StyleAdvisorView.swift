//
//  StyleAdvisorView.swift
//  OutfitMatch
//
//  Upload a photo of yourself or an outfit, ask a styling question (e.g.
//  "what shoes go with these jeans, casual Gen Z style?"), and Claude looks
//  at the photo to give real advice plus shoppable recommendations.

import SwiftUI
import PhotosUI

struct StyleAdvisorView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var question = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var advice: StyleAdvice?
    @State private var navigateToResults = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 280)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)
                                Text("Add a photo of yourself or your outfit")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        )
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                TextField(
                    "What shoes go with these jeans? Casual Gen Z style…",
                    text: $question,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Get Style Advice", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedImage == nil || trimmedQuestion.isEmpty || isSubmitting)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Style Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResults) {
            if let advice {
                StyleAdviceResultsView(advice: advice)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard let selectedImage, !trimmedQuestion.isEmpty else { return }

        errorMessage = nil
        Task {
            isSubmitting = true
            do {
                advice = try await StyleAdviceService.getAdvice(image: selectedImage, question: trimmedQuestion)
                isSubmitting = false
                navigateToResults = true
            } catch {
                isSubmitting = false
                errorMessage = errorText(for: error)
            }
        }
    }

    private func errorText(for error: Error) -> String {
        switch error {
        case StyleAdviceServiceError.server(let message):
            return message
        default:
            return "Couldn't reach the server. Make sure the backend is running."
        }
    }
}

#Preview {
    NavigationStack {
        StyleAdvisorView()
    }
}
