import Foundation

nonisolated extension Error {
    /// True for the error of a superseded request: the cancellation itself, or
    /// a real failure that arrived after the task was cancelled. The vendored
    /// request layers ignore cancellation, so a stale request can still fail;
    /// its error is as stale as its data and must not reach model state.
    var isCancellation: Bool {
        self is CancellationError || Task.isCancelled
    }
}
