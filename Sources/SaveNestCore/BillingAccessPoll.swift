import Foundation

/// Polls only server-verified access; a browser redirect never grants access itself.
@MainActor
public enum BillingAccessPoll {
    public static func run(
        until deadline: Date,
        now: () -> Date = Date.init,
        sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) },
        check: () async -> Bool
    ) async -> Bool {
        while !Task.isCancelled && now() < deadline {
            if await check() { return !Task.isCancelled }
            guard !Task.isCancelled else { return false }
            let remaining = deadline.timeIntervalSince(now())
            guard remaining > 0 else { return false }
            do { try await sleep(min(5, remaining)) } catch { return false }
        }
        return false
    }
}
