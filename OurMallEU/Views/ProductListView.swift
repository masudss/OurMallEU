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

private struct ProductFilterSheet: View {
    let availableCategories: [String]
    @Binding var filter: ProductFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $filter.selectedCategory) {
                        Text("All categories")
                            .tag(Optional<String>.none)
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category.capitalized)
                                .tag(Optional(category))
                        }
                    }
                }
                
                Section("Price") {
                    Picker("Price range", selection: $filter.priceFilter) {
                        Text("All prices")
                            .tag(Optional<ProductPriceFilter>.none)
                        ForEach(ProductPriceFilter.allCases) { priceFilter in
                            Text(priceFilter.rawValue)
                                .tag(Optional(priceFilter))
                        }
                    }
                }
                
                Section("Stock") {
                    Toggle("In stock only", isOn: $filter.inStockOnly)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        filter = .default
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HeroCarouselView: View {
    let banners: [URL]
    @State private var selectedBanner = 0

    var body: some View {
        TabView(selection: $selectedBanner) {
            ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: banner) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        default:
                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(index == 0 ? "Fresh drops" : index == 1 ? "Weekend deals" : "Vendor spotlight")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Browse curated picks from independent vendors across fashion, tech, and home.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .padding(18)
                    .padding(.bottom, 12)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .tag(index)
            }
        }
        .frame(height: 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .task {
            guard banners.count > 1 else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        selectedBanner = (selectedBanner + 1) % banners.count
                    }
                }
            }
        }
    }
}

private struct AddedToCartOverlay: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(26)
                .background(Color.green, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.08))
        .allowsHitTesting(false)
    }
}

private struct ProductGridCard: View {
    let product: Product
    let quantityInCart: Int
    let onTap: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardSize = geometry.size

            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: product.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardSize.width - 28, height: 170)
                                .clipped()
                        default:
                            ZStack {
                                Color.blue.opacity(0.08)
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.blue.opacity(0.7))
                            }
                            .frame(width: cardSize.width - 28, height: 170)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    if quantityInCart > 0 {
                        Text("\(quantityInCart)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue, in: Capsule())
                            .padding(10)
                    }
                }
                .frame(height: 170)

                Text(product.vendor.name.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(height: 48, alignment: .topLeading)

                HStack(spacing: 6) {
                    Text(product.discountedPrice.currencyText)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    if product.discountPercentage > 0 {
                        Text(product.price.currencyText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                    }
                }
                .frame(height: 28, alignment: .leading)

                Text(product.offerEndsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)

                Label(product.inStock ? "In stock" : "Out of stock", systemImage: product.inStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(product.inStock ? .green : .red)
                    .frame(height: 20, alignment: .leading)

                Spacer(minLength: 0)

                Button(product.inStock ? (quantityInCart > 0 ? "Add more" : "Add to cart") : "Unavailable") {
                    onAddToCart()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!product.inStock)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(width: cardSize.width, height: cardSize.height, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
            .onTapGesture(perform: onTap)
        }
        .frame(height: 390)
    }
}

#Preview {
    NavigationStack {
        ProductListView()
            .environmentObject(AppState.preview)
    }
}
