import SwiftData
import SwiftUI

struct ClosetView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(
        filter: #Predicate<WardrobeItem> { $0.isArchived == false },
        sort: \WardrobeItem.createdAt,
        order: .reverse
    )
    private var items: [WardrobeItem]

    @State private var filter: CategoryFilter = .all
    @State private var showingAddSheet = false

    private var filteredItems: [WardrobeItem] {
        items.filter { filter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No Clothes Yet", systemImage: "tshirt")
                    } description: {
                        Text("Photograph or import your clothing to start building your closet.")
                    } actions: {
                        Button("Add Item") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing in \(filter.title)", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("You haven't added anything in this category yet.")
                    } actions: {
                        Button("Add Item") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Show All Items") {
                            filter = .all
                        }
                    }
                } else {
                    itemGrid
                }
            }
            .navigationTitle("Closet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CategoryFilterPicker(filter: $filter)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") {
                        showingAddSheet = true
                    }
                }
            }
            .navigationDestination(for: WardrobeItem.self) { item in
                WardrobeItemDetailView(item: item)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddWardrobeItemSheet()
            }
        }
    }

    /// Wide layouts get more, smaller cells; compact keeps the larger cards.
    private var gridSpacing: CGFloat {
        horizontalSizeClass == .regular ? 10 : 12
    }

    private var gridColumns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: gridSpacing)]
            : [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: gridSpacing)]
    }

    private var itemGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(filteredItems) { item in
                    NavigationLink(value: item) {
                        WardrobeItemCell(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

private struct WardrobeItemCell: View {
    let item: WardrobeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MediaImageView(
                asset: item.thumbnailImage ?? item.displayImage,
                placeholderSymbol: "tshirt"
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(item.name)
                .font(.footnote.weight(.medium))
                .lineLimit(1)

            if let kind = item.categoryKind {
                Label(kind.displayName, systemImage: kind.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
