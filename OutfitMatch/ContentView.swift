//
//  ContentView.swift
//  OutfitMatch
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var detectedCategories: [ClothingCategory] = []
    @State private var navigateToResults = false
    @State private var isCheckingPhoto = false
    @State private var showNoClothingAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 320)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("Choose a photo of an outfit or item")
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
                .padding(.horizontal)

                Button {
                    findMatches()
                } label: {
                    if isCheckingPhoto {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Find Matches", systemImage: "sparkle.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedImage == nil || isCheckingPhoto)
                .padding(.horizontal)

                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    ChatView()
                } label: {
                    Label("Describe It", systemImage: "bubble.left.and.text.bubble.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("OutfitMatch")
            .navigationDestination(isPresented: $navigateToResults) {
                if let selectedImage {
                    ResultsView(capturedImage: selectedImage, categories: detectedCategories)
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
            .alert("No Outfit Found", isPresented: $showNoClothingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn't find any clothing in this photo. Please add a photo with an outfit or clothing item.")
            }
        }
    }

    private func findMatches() {
        guard let selectedImage else { return }
        Task {
            isCheckingPhoto = true
            let categories = await ClothingDetector.analyzeAll(selectedImage)
            isCheckingPhoto = false

            if categories.isEmpty {
                showNoClothingAlert = true
            } else {
                detectedCategories = categories
                navigateToResults = true
            }
        }
    }
}

#Preview {
    ContentView()
}
