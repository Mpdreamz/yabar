/// Turns pokes into snapshots: a burst of pokes (a window moving fires many) becomes one query, `delay` after the
/// first.
/// A poke during a query schedules one more, so the last snapshot always reflects the last poke; an answer that
/// arrives after a newer one is dropped.
public actor Refresher {
    public typealias Query = @Sendable () async throws(YabaiError) -> Snapshot

    public nonisolated let results: AsyncStream<Result<Snapshot, YabaiError>>
    private let continuation: AsyncStream<Result<Snapshot, YabaiError>>.Continuation
    private let query: Query
    private let delay: Duration
    private var scheduled = false
    private var issued = 0
    private var delivered = 0

    public init(delay: Duration = .milliseconds(16), query: @escaping Query) {
        self.delay = delay
        self.query = query
        (results, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public func poke() {
        guard !scheduled else { return }
        scheduled = true
        Task { await run() }
    }

    public func finish() {
        continuation.finish()
    }

    private func run() async {
        try? await Task.sleep(for: delay)
        scheduled = false
        issued += 1
        let ticket = issued
        let result: Result<Snapshot, YabaiError>
        do {
            result = try await .success(query())
        } catch {
            result = .failure(error)
        }
        guard ticket > delivered else { return }
        delivered = ticket
        continuation.yield(result)
    }
}
