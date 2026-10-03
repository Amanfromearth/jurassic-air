import AppKit

final class ReminderDispatcher {
    weak var screenManager: ScreenManager?

    func fire(_ event: ReminderEvent) {
        guard let controller = screenManager?.controllerForMainScreen() else {
            Log.write("Dispatcher: no overlay controller for main screen — plane NOT spawned for '\(event.title)'")
            return
        }
        controller.scene.spawn(event: event)
    }
}
