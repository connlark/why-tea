enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)
}

/// Lets `@Observable` skip notifying when an identical state is written.
extension LoadState: Equatable where Value: Equatable {}
