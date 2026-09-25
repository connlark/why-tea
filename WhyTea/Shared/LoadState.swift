enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)
}
