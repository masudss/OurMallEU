import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let product: Product
    @State private var selection: ProductSelection
    @State private var showAddConfirmation = false
    @State private var showAddedToCartIndicator = false

    init(product: Product) {
        self.product = product
        _selection = State(initialValue: product.defaultSelection)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GeometryReader { geometry in
                    let contentWidth = geometry.size.width

                    AsyncImage(url: product.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: contentWidth, height: 320)
                                .clipped()
                        default:
                            LinearGradient(colors: [.blue.opacity(0.8), .cyan.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .frame(width: contentWidth, height: 320)
                                .clipped()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .frame(height: 320)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(product.vendor.name.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text(product.name)
                            .font(.largeTitle.bold())

                        Text(product.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Text(product.discountedPrice.currencyText)
                                .font(.title.bold())
                            if product.discountPercentage > 0 {
                                Text(product.price.currencyText)
                                    .foregroundStyle(.secondary)
                                    .strikethrough()
                            }
                        }

                        HStack(spacing: 14) {
                            Label(product.offerEndsText, systemImage: "timer")
                            Label(product.inStock ? "In stock" : "Out of stock", systemImage: product.inStock ? "shippingbox.fill" : "xmark.octagon.fill")
                                .foregroundStyle(product.inStock ? .green : .red)
                        }
                        .font(.subheadline)
                    }

                    if !product.options.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Options")
                                .font(.headline)

                            ForEach(product.options) { option in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(option.displayName)
                                        .font(.subheadline.weight(.semibold))

                                    Menu {
                                        ForEach(option.values, id: \.self) { value in
                                            Button(value) {
                                                selection.selectedOptions[option.name] = value
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selection.selectedOptions[option.name] ?? option.values.first ?? "Select")
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quantity")
                            .font(.headline)

                        Stepper(value: $selection.quantity, in: 1...max(1, product.quantityRemaining)) {
                            Text("\(selection.quantity)")
                                .font(.title3.bold())
                        }
                        .disabled(!product.inStock)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
        .navigationTitle("Product")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showAddedToCartIndicator {
                AddedToCartFeedbackOverlay()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .alert("Add item to cart?", isPresented: $showAddConfirmation) {
            Button("No", role: .cancel) {}
            Button("Yes") {
                appState.addToCart(product, selection: selection)
                showAddedConfirmation()
            }
        } message: {
            Text("Add \(product.name) to your cart?")
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showAddConfirmation = true
            } label: {
                Text(product.inStock ? "Add \(selection.quantity) to cart" : "Unavailable")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!product.inStock)
            .padding()
            .background(.thinMaterial)
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
                dismiss()
            }
        }
    }
}

private struct AddedToCartFeedbackOverlay: View {
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

#Preview {
    NavigationStack {
        ProductDetailView(product: Product.sampleProducts[0])
            .environmentObject(AppState.preview)
    }
}
