import SwiftUI

/// The material of a piece, under it in the hand: "Pierre", "↑ Ressort".
struct PieceBadge: View {
    let kind: BlockKind

    var body: some View {
        let definition = BlockCatalog.definition(for: kind)
        HStack(spacing: 2) {
            if definition.power != .none || kind == .gold {
                Image(systemName: definition.symbol)
                    .imageScale(.small)
            }
            Text(definition.name)
        }
        .font(.caption2.weight(.bold))
        .fontDesign(.rounded)
        .lineLimit(1)
        .foregroundStyle(.secondary)
    }
}

enum PieceName {
    /// "Pierre en L", "Or en domino": the material, then the shape.
    static func of(_ kind: BlockKind, _ shape: BlockShape) -> String {
        String(localized: "\(BlockCatalog.definition(for: kind).name) en \(shape.family.name)")
    }
}
