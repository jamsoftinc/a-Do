import Foundation
import Observation

@MainActor
@Observable
final class ReminderMutationMonitor {
    static let shared = ReminderMutationMonitor()

    private(set) var revision: Int = 0
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    private init() {}

    func notifyChange() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self, !Task.isCancelled else { return }
            self.revision &+= 1
        }
    }

    func reset() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}
