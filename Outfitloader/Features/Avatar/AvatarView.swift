import SwiftData
import SwiftUI

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
        }
    }

    private func avatarForm(_ avatar: AvatarProfile) -> some View {
        Form {
            Section {
                MediaImageView(
                    asset: avatar.silhouetteImage ?? avatar.sourceImage,
                    placeholderSymbol: "person.crop.rectangle"
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

    private func displayNameBinding(for avatar: AvatarProfile) -> Binding<String> {
        Binding {
            avatar.displayName ?? ""
        } set: { newValue in
            avatar.displayName = newValue.isEmpty ? nil : newValue
            avatar.updatedAt = .now
        }
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
