import SwiftUI

struct ProductFilterSheet: View {
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

struct HeroCarouselView: View {
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

struct AddedToCartOverlay: View {
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

struct ProductGridCard: View {
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
