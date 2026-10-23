import Foundation

/// One run-loop deadline. Precise user reminders may prevent App Nap while
/// pending, but never prevent the Mac from sleeping or disable timer coalescing.
final class DeadlineTimer {
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private(set) var nextFireDate: Date?

    func schedule(at date: Date?, tolerance: TimeInterval = 0.25,
                  keepsAppResponsive: Bool = true, action: @escaping () -> Void) {
        guard date != nextFireDate else { return }
        cancel()
        guard let date else { return }
        nextFireDate = date
        if keepsAppResponsive {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Deliver a scheduled Jurassic Air reminder"
            )
        }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.cancel()
            action()
        }
        timer.tolerance = tolerance
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        nextFireDate = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    deinit { cancel() }
}
