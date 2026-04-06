import Foundation

extension AppState {
    func goToCart() {
        path.append(.cart)
    }

    func goToOrders() {
        path.append(.orders)
    }

    func goToOrderDetails(_ orderID: String) {
        path.append(.orderDetails(orderID))
    }

    func goToProduct(_ product: Product) {
        path.append(.product(product))
    }

    func goToCheckout() {
        guard !selectedSections.isEmpty else { return }
        path.append(.checkout)
    }

    func goToPayment() {
        guard !selectedSections.isEmpty else { return }
        path.append(.payment)
    }

    func goHome() {
        path.removeAll()
    }
}
