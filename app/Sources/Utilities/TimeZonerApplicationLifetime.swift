/// Keeps the AppKit delegate alive while the application run loop is active.
public final class TimeZonerApplicationLifetime<Delegate: AnyObject> {
    private let delegate: Delegate

    public init(retaining delegate: Delegate) {
        self.delegate = delegate
    }

    public func run(_ body: () -> Void) {
        withExtendedLifetime(delegate, body)
    }
}
