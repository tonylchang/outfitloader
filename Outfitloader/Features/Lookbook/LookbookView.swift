import SwiftData
import SwiftUI

struct LookbookView: View {
    @Query(
        filter: #Predicate<OutfitLook> { $0.isArchived == false },
        sort: \OutfitLook.createdAt,
        order: .reverse
    )
    private var looks: [OutfitLook]

    var body: some View {
        NavigationStack {
            Group {
                if looks.isEmpty {
                    ContentUnavailableView {
                        Label("No Looks Yet", systemImage: "rectangle.grid.2x2")
                    } description: {
                        Text("Assemble an outfit in Try On. Saving looks to the lookbook arrives in an upcoming build.")
                    }
                } else {
                    lookGrid
                }
            }
            .navigationTitle("Lookbook")
        }
    }

    private var lookGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)],
                spacing: 12
            ) {
                ForEach(looks) { look in
                    VStack(alignment: .leading, spacing: 6) {
                        MediaImageView(asset: look.previewImage, placeholderSymbol: "rectangle.grid.2x2")
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Text(look.name)
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                    }
                }
            }
            .padding()
        }
    }
}
