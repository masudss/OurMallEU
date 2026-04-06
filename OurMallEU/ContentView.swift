import SwiftUI

enum AppRoute: Hashable {
    case cart
    case orders
    case orderDetails(String)
    case product(Product)
    case checkout
    case payment
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isShowingSplash {
                SplashView()
            } else {
                NavigationStack(path: $appState.path) {
                    ProductListView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .cart:
                                CartView()
                            case .orders:
                                OrdersView()
                            case .orderDetails(let orderID):
                                OrderDetailsView(orderID: orderID)
                            case .product(let product):
                                ProductDetailView(product: product)
                            case .checkout:
                                CheckoutView()
                            case .payment:
                                PaymentView()
                            }
                        }
                }
            }
        }
        .task {
            appState.start()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.preview)
}
