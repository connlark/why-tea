/// A search asked for from outside the Search screen, such as a launch
/// argument. `id` distinguishes repeated requests for the same query.
struct SearchRequest: Hashable {
    let query: String
    let id: Int
}
