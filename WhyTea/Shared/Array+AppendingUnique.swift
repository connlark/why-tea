extension Array where Element: Identifiable {
    /// YouTube continuations sometimes repeat items; `ForEach` needs unique IDs.
    func appendingUnique(_ newElements: [Element]) -> [Element] {
        var seen = Set(map(\.id))
        return self + newElements.filter { seen.insert($0.id).inserted }
    }
}
