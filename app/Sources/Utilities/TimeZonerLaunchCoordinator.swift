import Foundation

public struct TimeZonerRunningInstance: Equatable {
    public let processID: Int32
    public let launchDate: Date?

    public init(processID: Int32, launchDate: Date?) {
        self.processID = processID
        self.launchDate = launchDate
    }
}

public enum TimeZonerLaunchCoordinator {
    public static func incumbent(
        currentProcessID: Int32,
        candidates: [TimeZonerRunningInstance]
    ) -> TimeZonerRunningInstance? {
        candidates
            .filter { $0.processID != currentProcessID }
            .min {
                ($0.launchDate ?? .distantFuture, $0.processID)
                    < ($1.launchDate ?? .distantFuture, $1.processID)
            }
    }
}

public final class TimeZonerDuplicateLaunchRouter {
    private let activateIncumbent: () -> Void
    private let forwardURL: (URL) -> Void

    public init(activateIncumbent: @escaping () -> Void, forwardURL: @escaping (URL) -> Void) {
        self.activateIncumbent = activateIncumbent
        self.forwardURL = forwardURL
    }

    public func didLaunch() {
        activateIncumbent()
    }

    public func open(urls: [URL]) {
        for url in urls where TimeZonerDeepLink.parse(url) != nil {
            forwardURL(url)
        }
    }
}
