import SwiftUI

enum CategoryFilter: Hashable {
    case all
    case kind(CategoryKind)

    var title: String {
        switch self {
        case .all:
            return "All"
        case .kind(let kind):
            return kind.displayName
        }
    }

    func matches(_ item: WardrobeItem) -> Bool {
        switch self {
        case .all:
            return true
        case .kind(let kind):
            return item.categoryKindRawValue == kind.rawValue
        }
    }
}

struct CategoryFilterPicker: View {
    @Binding var filter: CategoryFilter

    var body: some View {
        Picker("Category", selection: $filter) {
            Text("All").tag(CategoryFilter.all)
            ForEach(CategoryKind.allCases) { kind in
                Label(kind.displayName, systemImage: kind.symbolName)
                    .tag(CategoryFilter.kind(kind))
            }
        }
        .pickerStyle(.menu)
    }
}
