import SwiftData
import SwiftUI
import UIKit

struct AvatarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
    @Query(filter: #Predicate<AvatarProfile> { $0.isActive })
    private var activeAvatars: [AvatarProfile]

    @State private var showingRecreateConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let avatar = activeAvatars.first {
                    avatarForm(avatar)
                } else {
                    ContentUnavailableView(
                        "No Active Avatar",
                        systemImage: "person.crop.rectangle",
                        description: Text("Avatar creation opens automatically when no avatar exists.")
                    )
                }
            }
            .navigationTitle("Avatar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
    }

    private func avatarForm(_ avatar: AvatarProfile) -> some View {
        Form {
            Section {
                AvatarBodyShapePreview(
                    asset: avatar.silhouetteImage ?? avatar.sourceImage,
                    adjustment: avatar.bodyShapeAdjustment
                )
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Details") {
                TextField(
                    "Name",
                    text: displayNameBinding(for: avatar),
                    prompt: Text("My Avatar")
                )

                LabeledContent(
                    "Silhouette",
                    value: avatar.processingStatus == .ready
                        ? "On-device silhouette"
                        : "Original photo (no silhouette)"
                )
            }

            bodyShapeSection(for: avatar)

            Section {
                Button("Recreate Avatar", role: .destructive) {
                    showingRecreateConfirmation = true
                }
            } footer: {
                Text("Recreating removes the current avatar photo and silhouette from this device and starts a new capture.")
            }
        }
        .confirmationDialog(
            "Recreate your avatar?",
            isPresented: $showingRecreateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete & Recreate", role: .destructive) {
                recreate(avatar)
            }
        } message: {
            Text("The current avatar photo and silhouette will be deleted from this device.")
        }
        .alert(
            "Couldn't Delete Avatar",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func bodyShapeSection(for avatar: AvatarProfile) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Avatar Height")
                    Spacer()
                    Text("\(Int((avatar.heightCentimeters ?? 170).rounded())) cm")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: heightBinding(for: avatar), in: 145...205, step: 1) {
                    Text("Avatar Height")
                }
            }

            adjustmentRow("Shoulders", value: bodyShapeBinding(for: avatar, keyPath: \.shoulderAdjustment))
            adjustmentRow("Torso", value: bodyShapeBinding(for: avatar, keyPath: \.torsoAdjustment))
            adjustmentRow("Waist", value: bodyShapeBinding(for: avatar, keyPath: \.waistAdjustment))
            adjustmentRow("Hips", value: bodyShapeBinding(for: avatar, keyPath: \.hipAdjustment))
            adjustmentRow("Legs", value: bodyShapeBinding(for: avatar, keyPath: \.legAdjustment))

            Button("Reset Body Shape") {
                resetBodyShape(for: avatar)
            }
            .disabled(avatar.bodyShapeAdjustment.isNeutral)
        } header: {
            Text("Body Shape")
        } footer: {
            Text("These controls only tune the avatar's visual proportions for outfit preview. They are stored on this device.")
        }
    }

    private func adjustmentRow(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel(for: value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: -1...1, step: 0.05) {
                Text(title)
            }
        }
    }

    private func valueLabel(for value: Double) -> String {
        if abs(value) < 0.001 {
            return "0"
        }

        return String(format: "%+.2f", value)
    }

    private func displayNameBinding(for avatar: AvatarProfile) -> Binding<String> {
        Binding {
            avatar.displayName ?? ""
        } set: { newValue in
            avatar.displayName = newValue.isEmpty ? nil : newValue
            avatar.updatedAt = .now
        }
    }

    private func heightBinding(for avatar: AvatarProfile) -> Binding<Double> {
        Binding {
            avatar.heightCentimeters ?? 170
        } set: { newValue in
            avatar.heightCentimeters = newValue
            avatar.updatedAt = .now
        }
    }

    private func bodyShapeBinding(
        for avatar: AvatarProfile,
        keyPath: ReferenceWritableKeyPath<AvatarProfile, Double>
    ) -> Binding<Double> {
        Binding {
            avatar[keyPath: keyPath]
        } set: { newValue in
            avatar[keyPath: keyPath] = newValue
            avatar.updatedAt = .now
        }
    }

    private func resetBodyShape(for avatar: AvatarProfile) {
        avatar.heightCentimeters = nil
        avatar.shoulderAdjustment = 0
        avatar.torsoAdjustment = 0
        avatar.waistAdjustment = 0
        avatar.hipAdjustment = 0
        avatar.legAdjustment = 0
        avatar.updatedAt = .now
    }

    private func recreate(_ avatar: AvatarProfile) {
        do {
            let repository = AvatarRepository(modelContext: modelContext, mediaStore: mediaStore)
            try repository.deleteAvatar(avatar)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AvatarBodyShapePreview: View {
    let asset: ImageAsset?
    let adjustment: AvatarBodyShapeAdjustment

    @Environment(\.mediaStore) private var mediaStore
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ContentUnavailableView(
                    "No Avatar Image",
                    systemImage: "person.crop.rectangle",
                    description: Text("Create an avatar to preview body-shape adjustments.")
                )
            }
        }
        .task(id: taskID) {
            await loadImage()
        }
    }

    private var taskID: String {
        "\(asset?.relativePath ?? "none")|\(adjustment.cacheKey)"
    }

    @MainActor
    private func loadImage() async {
        guard let asset else {
            image = nil
            return
        }

        let store = mediaStore
        let relativePath = asset.relativePath
        let kindRawValue = asset.kindRawValue
        let adjustment = adjustment

        image = await Task.detached(priority: .userInitiated) {
            guard let source = store.loadImage(relativePath: relativePath, kindRawValue: kindRawValue) else {
                return nil
            }

            return AvatarBodyShapeRenderer().render(source, adjustment: adjustment)
        }.value
    }
}
