import SwiftUI

struct ProductListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var productPendingConfirmation: Product?
    @State private var showAddedToCartIndicator = false
    @State private var searchText = ""
    @State private var productFilter = ProductFilter.default
    @State private var showFilterSheet = false

    private let horizontalPadding: CGFloat = 16
    private let gridSpacing: CGFloat = 14
    
    private var filteredProducts: [Product] {
        appState.filteredProducts(matching: searchText, filter: productFilter)
    }

    var body: some View {
        Group {
            if appState.isLoadingProducts {
                ProgressView("Loading products...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = appState.productErrorMessage, appState.products.isEmpty {
                ContentUnavailableView {
                    Label("Products unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        appState.retryLoadingProducts()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                
                                TextField("Search products", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            
                            Button {
                                showFilterSheet = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    
                                    if productFilter.isActive {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 10, height: 10)
                                            .offset(x: 3, y: -3)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Filters")
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        HeroCarouselView(banners: appState.heroBanners)
                            .padding(.horizontal, horizontalPadding)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Featured products")
                                .font(.title2.bold())
                            Text("Multi-vendor picks with live stock, offers, and configurable options.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if !searchText.isEmpty || productFilter.isActive {
                                Text("\(filteredProducts.count) result\(filteredProducts.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)

                        if filteredProducts.isEmpty {
                            ContentUnavailableView(
                                "No products found",
                                systemImage: "magnifyingglass",
                                description: Text("Try a different keyword or clear some filters.")
                            )
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 40)
                        } else {
                            GeometryReader { geometry in
                                let contentWidth = geometry.size.width - (horizontalPadding * 2)
                                let cardWidth = floor((contentWidth - gridSpacing) / 2)
                                let rows = productRows

                                VStack(alignment: .leading, spacing: gridSpacing) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                                        HStack(alignment: .top, spacing: gridSpacing) {
                                            ForEach(row) { product in
                                                ProductGridCard(
                                                    product: product,
                                                    quantityInCart: appState.quantityInCart(for: product),
                                                    onTap: { appState.goToProduct(product) },
                                                    onAddToCart: { productPendingConfirmation = product }
                                                )
                                                .frame(width: cardWidth)
                                                .onAppear {
                                                    appState.loadNextPageIfNeeded(currentProduct: product)
                                                }
                                            }
                                            
                                            if row.count == 1 {
                                                Color.clear
                                                    .frame(width: cardWidth, height: 1)
                                            }
                                        }
                                    }
                                }
                                .frame(width: contentWidth, alignment: .leading)
                                .padding(.horizontal, horizontalPadding)
                            }
                            .frame(height: gridHeight(for: filteredProducts.count))
                        }

                        if appState.isLoadingNextPage {
                            HStack {
                                Spacer()
                                ProgressView("Loading more...")
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }

                        if let errorMessage = appState.productErrorMessage, !appState.products.isEmpty {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, horizontalPadding)
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Products")
        .sheet(isPresented: $showFilterSheet) {
            ProductFilterSheet(
                availableCategories: appState.availableProductCategories,
                filter: $productFilter
            )
        }
        .overlay {
            if showAddedToCartIndicator {
                AddedToCartOverlay()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .alert(
            "Add item to cart?",
            isPresented: Binding(
                get: { productPendingConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        productPendingConfirmation = nil
                    }
                }
            ),
            presenting: productPendingConfirmation
        ) { product in
            Button("No", role: .cancel) {
                productPendingConfirmation = nil
            }
            Button("Yes") {
                appState.addToCart(product)
                productPendingConfirmation = nil
                showAddedConfirmation()
            }
        } message: { product in
            Text("Add \(product.name) to your cart?")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.goToOrders()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox")
                            .font(.subheadline.weight(.semibold))
                        Text("Orders")
                            .font(.subheadline.weight(.semibold))
                        if appState.ordersCount > 0 {
                            Text("\(appState.ordersCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Orders")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.goToCart()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "cart")
                            .font(.title3)
                            .padding(12)

                        if appState.cartCount > 0 {
                            Text("\(appState.cartCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.red, in: Circle())
                                .offset(x: 2, y: -2)
                                .padding(5)
                        }
                    }
                    .padding(.trailing, 10)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cart")
            }
        }
    }

    private func gridHeight(for productCount: Int) -> CGFloat {
        let rows = Int(ceil(Double(productCount) / 2.0))
        return CGFloat(rows) * 404 + CGFloat(max(0, rows - 1)) * gridSpacing
    }

    private var productRows: [[Product]] {
        stride(from: 0, to: filteredProducts.count, by: 2).map { index in
            Array(filteredProducts[index..<min(index + 2, filteredProducts.count)])
        }
    }

    private func showAddedConfirmation() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAddedToCartIndicator = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showAddedToCartIndicator = false
                }
            }
        }
    }
}
#Preview {
    NavigationStack {
        ProductListView()
            .environmentObject(AppState.preview)
    }
}
