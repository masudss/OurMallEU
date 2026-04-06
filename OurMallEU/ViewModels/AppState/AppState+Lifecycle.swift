import Foundation

extension AppState {
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            isShowingSplash = false
            await refreshProducts()
        }
    }
}
