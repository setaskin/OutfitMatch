//
//  StyleAdvisorView.swift
//  OutfitMatch
//
//  Upload a photo of yourself or an outfit, ask a styling question (e.g.
//  "what shoes go with these jeans, casual Gen Z style?"), and Claude looks
//  at the photo to give real advice plus shoppable recommendations.
//
//  Free tier: a few free style checks (StyleAdvisorAccess), then it
//  requires the Style Advisor Premium subscription (SubscriptionManager).

import SwiftUI
import PhotosUI

struct StyleAdvisorView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var access = StyleAdvisorAccess()

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var question = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var advice: StyleAdvice?
    @State private var navigateToResults = false
    @State private var showCamera = false

    private let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    private var hasAccess: Bool {
        subscriptionManager.isSubscribed || access.freeUsesRemaining > 0
    }

    var body: some View {
        Group {
            if hasAccess {
                form
            } else {
                StyleAdvisorPaywallView(subscriptionManager: subscriptionManager)
            }
        }
        .navigationDestination(isPresented: $navigateToResults) {
            if let advice {
                StyleAdviceResultsView(advice: advice)
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Selected photo")
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.scanSurface)
                        .frame(height: 280)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.scanInkDim)
                                    .accessibilityHidden(true)
                                Text("Add a photo of yourself or your outfit")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.scanInkDim)
                            }
                        )
                }

                HStack(spacing: 12) {
                    if isCameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .font(ScanFont.display(14, weight: .semibold))
                                .foregroundStyle(Color.scanInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.scanHairline, lineWidth: 1.5)
                                )
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Library", systemImage: "photo.on.rectangle")
                            .font(ScanFont.display(14, weight: .semibold))
                            .foregroundStyle(Color.scanInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.scanHairline, lineWidth: 1.5)
                            )
                    }
                }

                TextField("", text: $question, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.scanInk)
                    .tint(Color.scanMint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .placeholder(when: question.isEmpty) {
                        Text("What shoes go with these jeans? Casual Gen Z style…")
                            .foregroundStyle(Color.scanInkDim)
                    }
                    .lineLimit(2...5)
                    .padding(12)
                    .background(Color.scanSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    submit()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color.scanBackground)
                        } else {
                            Label("Get Style Advice", systemImage: "sparkles")
                                .font(ScanFont.display(15, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.scanBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        (selectedImage == nil || trimmedQuestion.isEmpty) ? Color.scanSurface : Color.scanMint
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedImage == nil || trimmedQuestion.isEmpty || isSubmitting)

                if !subscriptionManager.isSubscribed {
                    Text("\(access.freeUsesRemaining) free style check\(access.freeUsesRemaining == 1 ? "" : "s") remaining")
                        .font(ScanFont.mono(11))
                        .foregroundStyle(Color.scanInkDim)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.scanAmber)
                }
            }
            .padding()
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Style Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture(image: $selectedImage)
                .ignoresSafeArea()
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
                if !subscriptionManager.isSubscribed {
                    access.consumeFreeUse()
                }
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

private extension View {
    @ViewBuilder
    func placeholder(when shouldShow: Bool, @ViewBuilder placeholder: () -> some View) -> some View {
        ZStack(alignment: .topLeading) {
            if shouldShow { placeholder().allowsHitTesting(false) }
            self
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        StyleAdvisorView()
    }
}
