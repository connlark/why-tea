/// Drives `SearchScreen`'s search task. `attempt` changes on every submit so
/// resubmitting or retrying the same query still restarts the task.
struct SearchSubmission: Equatable {
    var query = ""
    var attempt = 0

    func resubmitted(query: String) -> SearchSubmission {
        SearchSubmission(query: query, attempt: attempt + 1)
    }
}
