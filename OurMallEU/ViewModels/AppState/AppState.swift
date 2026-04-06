import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var isShowingSplash = true
    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var isLoadingNextPage = false
    @Published var productErrorMessage: String?
    @Published var cartItems: [String: CartItem] = [:]
    @Published var selectedVendorIDs: Set<String> = []
    @Published var isSubmittingPayment = false
    @Published var paymentErrorMessage: String?
    @Published var paymentReference: String?
    @Published var currentOrder: Order?
    @Published var successfulOrders: [Order] = []
    @Published var hasCompletedPayment = false

    let heroBanners: [URL] = [
        URL(string: "https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1400&q=80")!,
        URL(string: "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=960&q=60")!,
        URL(string: "https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=960&q=60")!
    ]

    let service: CommerceServicing
    let pageSize = 6
    var hasStarted = false
    var isUsingFallbackProducts = false
    var currentPage = 0
    var hasMoreProducts = true

    init(service: CommerceServicing? = nil) {
        self.service = service ?? CommerceAPIClient()
    }

    static let preview = AppState(service: PreviewCommerceService())
}
