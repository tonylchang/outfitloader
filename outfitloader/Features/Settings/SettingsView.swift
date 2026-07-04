import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
    @Environment(\.dismiss) private var dismiss

    @Query private var avatars: [AvatarProfile]
    @Query private var wardrobeItems: [WardrobeItem]
    @Query private var looks: [OutfitLook]

    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Privacy") {
                Label("Photos and generated images stay on this device.", systemImage: "lock")
                Label("No analytics or behavioral tracking.", systemImage: "chart.bar.xaxis")
                Label("No third-party AI services.", systemImage: "network.slash")
            }

            Section("Local Data") {
                LabeledContent("Avatars", value: "\(avatars.count)")
                LabeledContent("Closet Items", value: "\(wardrobeItems.count)")
                LabeledContent("Saved Looks", value: "\(looks.count)")

                if isDeleting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Deleting local data...")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Delete All Local Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .disabled(isDeleting || (avatars.isEmpty && wardrobeItems.isEmpty && looks.isEmpty))
            } footer: {
                Text("This removes avatar photos, wardrobe photos, saved looks, generated previews, and related local metadata from this device.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete all local data?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Local Data", role: .destructive) {
                deleteAllLocalData()
            }
        } message: {
            Text("This cannot be undone. You will return to avatar setup after deletion.")
        }
        .alert(
            "Couldn't Delete Local Data",
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

    private func deleteAllLocalData() {
        isDeleting = true
        Task {
            do {
                let repository = LocalDataRepository(modelContext: modelContext, mediaStore: mediaStore)
                try await repository.deleteAllUserData()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }

            isDeleting = false
        }
    }
}
