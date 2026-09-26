/// Every sheet the shell can present, resolved by `SheetDestinationView`.
enum SheetDestination: Hashable, Identifiable {
    /// Paste or type a YouTube link. `text` seeds the field, for example with
    /// an incoming link that did not parse.
    case openLink(text: String = "")

    var id: Self { self }
}
