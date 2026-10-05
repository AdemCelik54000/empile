import CoreGraphics

/// The family a piece belongs to: it keeps its name whichever way it is turned.
enum ShapeFamily: String, CaseIterable, Sendable {
    case mono
    case domino
    case bar3
    case corner
    case bar4
    case square
    case t
    case l
    case j
    case s
    case z
    /// Any other rectangle (used by tests and simple layouts).
    case block

    var name: String {
        switch self {
        case .mono: String(localized: "carré simple")
        case .domino: String(localized: "domino")
        case .bar3: String(localized: "barre de 3")
        case .corner: String(localized: "coin")
        case .bar4: String(localized: "barre de 4")
        case .square: String(localized: "gros carré")
        case .t: String(localized: "T")
        case .l: String(localized: "L")
        case .j: String(localized: "J")
        case .s: String(localized: "S")
        case .z: String(localized: "Z")
        case .block: String(localized: "bloc")
        }
    }
}

/// One square of a piece, counted from the bottom-left of its bounding box.
struct GridCell: Hashable, Comparable, Sendable {
    let column: Int
    let row: Int

    static func < (lhs: GridCell, rhs: GridCell) -> Bool {
        (lhs.row, lhs.column) < (rhs.row, rhs.column)
    }
}

/// A piece made of grid squares, like a Tetris piece. Cells are kept sorted and packed against the origin,
/// so two pieces with the same squares are equal.
struct BlockShape: Hashable, Sendable {
    let family: ShapeFamily
    let cells: [GridCell]
    /// Width of the bounding box, in squares.
    let columns: Int
    /// Height of the bounding box, in squares.
    let rows: Int

    init(_ family: ShapeFamily, cells: [GridCell]) {
        let minColumn = cells.map(\.column).min() ?? 0
        let minRow = cells.map(\.row).min() ?? 0
        let packed = Set(cells.map { GridCell(column: $0.column - minColumn, row: $0.row - minRow) }).sorted()
        self.family = family
        self.cells = packed
        columns = (packed.map(\.column).max() ?? -1) + 1
        rows = (packed.map(\.row).max() ?? -1) + 1
    }

    /// Draws a piece as text, top row first: "X" is a square, anything else is empty.
    init(_ family: ShapeFamily, _ pattern: [String]) {
        var cells: [GridCell] = []
        for (index, line) in pattern.enumerated() {
            let row = pattern.count - 1 - index
            for (column, character) in line.enumerated() where character == "X" {
                cells.append(GridCell(column: column, row: row))
            }
        }
        self.init(family, cells: cells)
    }

    /// A full rectangle of squares.
    static func rectangle(columns: Int, rows: Int, family: ShapeFamily = .block) -> BlockShape {
        let cells = (0..<max(rows, 1)).flatMap { row in
            (0..<max(columns, 1)).map { GridCell(column: $0, row: row) }
        }
        return BlockShape(family, cells: cells)
    }

    /// Number of squares.
    var area: Int { cells.count }

    /// The same piece turned a quarter turn clockwise.
    var quarterTurned: BlockShape {
        BlockShape(family, cells: cells.map { GridCell(column: $0.row, row: columns - 1 - $0.column) })
    }

    /// Looks the same after a quarter turn, so turning it is pointless.
    var isTurnInvariant: Bool { quarterTurned == self }

    /// Size of the bounding box.
    func size(unit: CGFloat) -> CGSize {
        CGSize(width: CGFloat(columns) * unit, height: CGFloat(rows) * unit)
    }

    /// Center of a square relative to the center of the bounding box.
    func offset(of cell: GridCell, unit: CGFloat) -> CGPoint {
        CGPoint(
            x: (CGFloat(cell.column) + 0.5 - CGFloat(columns) / 2) * unit,
            y: (CGFloat(cell.row) + 0.5 - CGFloat(rows) / 2) * unit
        )
    }

    /// Squares grouped into horizontal runs, bottom row first: fewer, larger rectangles for physics bodies.
    var horizontalRuns: [(row: Int, firstColumn: Int, length: Int)] {
        var runs: [(row: Int, firstColumn: Int, length: Int)] = []
        for cell in cells {
            if let last = runs.last, last.row == cell.row, last.firstColumn + last.length == cell.column {
                runs[runs.count - 1].length += 1
            } else {
                runs.append((cell.row, cell.column, 1))
            }
        }
        return runs
    }

    func contains(column: Int, row: Int) -> Bool {
        cells.contains(GridCell(column: column, row: row))
    }
}

/// The pieces of the game.
extension BlockShape {
    static let mono = BlockShape(.mono, ["X"])
    static let domino = BlockShape(.domino, ["XX"])
    static let bar3 = BlockShape(.bar3, ["XXX"])
    static let corner = BlockShape(.corner, ["X.", "XX"])
    static let bar4 = BlockShape(.bar4, ["XXXX"])
    static let square = BlockShape(.square, ["XX", "XX"])
    static let t = BlockShape(.t, ["XXX", ".X."])
    static let l = BlockShape(.l, ["X.", "X.", "XX"])
    static let j = BlockShape(.j, [".X", ".X", "XX"])
    static let s = BlockShape(.s, [".XX", "XX."])
    static let z = BlockShape(.z, ["XX.", ".XX"])
}
