enum PowerRules {
    /// Glass pieces carrying more pieces than they can hold: they should shatter now.
    /// - Parameter ignoring: Pieces that can no longer break (frozen out of sight).
    static func overloadedBlocks(in tower: TowerSnapshot, maxLoad: Int, ignoring: Set<Int> = []) -> [Int] {
        tower.blocks.compactMap { block in
            guard BlockCatalog.definition(for: block.kind).power == .shattersUnderLoad,
                  !ignoring.contains(block.id)
            else { return nil }
            return tower.blocksAbove(block).count > maxLoad ? block.id : nil
        }
    }
}
