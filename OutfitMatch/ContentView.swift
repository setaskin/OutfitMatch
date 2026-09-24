//
//  ContentView.swift
//  OutfitMatch
//
//  "Scan Line" home screen — a dark, viewfinder-styled entry point that
//  visually signals what the app actually does: a camera + on-device
//  vision reading the photo.

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var detectedCategories: [ClothingCategory] = []
    @State private var navigateToResults = false
    @State private var isCheckingPhoto = false
    @State private var showNoClothingAlert = false
    @State private var showCamera = false

    private let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.scanBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        viewfinder
                        headline

                        HStack(spacing: 10) {
                            if isCameraAvailable {
                                scanButton
                            }
                            libraryButton
                        }

                        findMatchesButton

                        // Top-aligned so the three cards stay level even when
                        // a longer title wraps to a second line.
                        HStack(alignment: .top, spacing: 10) {
                            entryCard(
                                title: "Describe It",
                                icon: "text.bubble",
                                iconColor: .scanAmber,
                                destination: ChatView()
                            )
                            entryCard(
                                title: "Style Advisor",
                                icon: "wand.and.stars",
                                iconColor: .scanMint,
                                destination: StyleAdvisorView()
                            )
                            entryCard(
                                title: "Talk to It",
                                icon: "waveform",
                                iconColor: .scanMint,
                                destination: ChatView(startInVoiceMode: true)
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraCapture(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .alert("No Outfit Found", isPresented: $showNoClothingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn't find any clothing in this photo. Please add a photo with an outfit or clothing item.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("OutfitMatch")
                .font(ScanFont.display(21, weight: .bold))
                .foregroundStyle(Color.scanInk)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color.scanMint).frame(width: 6, height: 6)
                Text(selectedImage == nil ? "READY" : "LOADED")
                    .font(ScanFont.mono(10, medium: true))
                    .tracking(0.5)
                    .foregroundStyle(Color.scanMint)
            }
        }
        .padding(.top, 8)
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.scanSurface)

            if let selectedImage {
                GeometryReader { geo in
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Selected photo")
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.scanHairline, style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                    .padding(44)
                    .accessibilityHidden(true)
            }

            ViewfinderCorners()
                .accessibilityHidden(true)

            // Only in the empty state: once a photo is in, it speaks for
            // itself and dim text over a bright image is just hard to read.
            // The earlier HUD faked instrument readouts here — including a
            // MATCH_CONF field that never had a value — which read as
            // unfinished placeholder text rather than as design.
            VStack {
                Spacer()
                HStack {
                    if selectedImage == nil {
                        Text("No photo yet")
                            .font(ScanFont.mono(10))
                            .foregroundStyle(Color.scanInkDim)
                    }
                    Spacer()
                }
            }
            // Clears the corner brackets, which reach ~36pt in from each edge.
            .padding(.horizontal, 46)
            .padding(.vertical, 18)
            .accessibilityHidden(true)
        }
        .frame(height: 340)
    }

    private var headline: some View {
        Text("Point your camera.\nWe'll take it from there.")
            .font(ScanFont.display(22, weight: .semibold))
            .foregroundStyle(Color.scanInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var scanButton: some View {
        Button {
            showCamera = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "camera.fill")
                    .accessibilityHidden(true)
                Text("Scan")
            }
            .font(ScanFont.display(14, weight: .bold))
            .foregroundStyle(Color.scanBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.scanAmber)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var libraryButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Text("Library")
                .font(ScanFont.display(14, weight: .semibold))
                .foregroundStyle(Color.scanInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.scanHairline, lineWidth: 1.5)
                )
        }
    }

    private var findMatchesButton: some View {
        Button {
            findMatches()
        } label: {
            Group {
                if isCheckingPhoto {
                    ProgressView()
                        .tint(Color.scanBackground)
                } else {
                    Text("Find Matches")
                        .font(ScanFont.display(15, weight: .bold))
                        .foregroundStyle(selectedImage == nil ? Color.scanInkDim : Color.scanBackground)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(selectedImage == nil ? Color.scanSurface : Color.scanMint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(selectedImage == nil || isCheckingPhoto)
    }

    private func entryCard(
        title: String,
        icon: String,
        iconColor: Color,
        destination: some View
    ) -> some View {
        NavigationLink {
            destination
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(ScanFont.display(13, weight: .semibold))
                    .foregroundStyle(Color.scanInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Equal heights across the row regardless of title wrapping.
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
            .padding(14)
            .background(Color.scanSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
