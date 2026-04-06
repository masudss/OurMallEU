import Foundation

extension AppState {
    func refreshProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        productErrorMessage = nil
        currentPage = 0
        hasMoreProducts = true
        products = []

        do {
            let firstPage = try await service.fetchProducts(page: 1, pageSize: pageSize)
            currentPage = firstPage.page
            hasMoreProducts = firstPage.hasMorePages
            products = firstPage.items
            isUsingFallbackProducts = false
        } catch {
            let fallbackPage = fallbackProductPage(page: 1)
            currentPage = fallbackPage.page
            hasMoreProducts = fallbackPage.hasMorePages
            products = fallbackPage.items
            isUsingFallbackProducts = true
            productErrorMessage = "Backend unavailable. Showing offline catalog."
        }

        isLoadingProducts = false
    }

    func retryLoadingProducts() {
        Task {
            await refreshProducts()
        }
    }

    func loadNextPageIfNeeded(currentProduct: Product) {
        guard hasMoreProducts, !isLoadingProducts, !isLoadingNextPage else { return }
        guard products.suffix(4).contains(where: { $0.id == currentProduct.id }) else { return }

        Task {
            await loadNextPage()
        }
    }

    func filteredProducts(matching query: String, filter: ProductFilter) -> [Product] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return products.filter { product in
            let matchesQuery: Bool
            if normalizedQuery.isEmpty {
                matchesQuery = true
            } else {
                let searchableText = [
                    product.name,
                    product.vendor.name,
                    product.summary,
                    product.category.joined(separator: " ")
                ]
                .joined(separator: " ")
                matchesQuery = searchableText.localizedCaseInsensitiveContains(normalizedQuery)
            }

            let matchesCategory = filter.selectedCategory.map { category in
                product.category.contains { $0.caseInsensitiveCompare(category) == .orderedSame }
            } ?? true
            let matchesPrice = filter.priceFilter?.matches(price: product.discountedPrice) ?? true
            let matchesStock = filter.inStockOnly ? product.inStock : true

            return matchesQuery && matchesCategory && matchesPrice && matchesStock
        }
    }

    private func loadNextPage() async {
        guard hasMoreProducts else { return }
        isLoadingNextPage = true

        let nextPage = currentPage + 1

        if isUsingFallbackProducts {
            let response = fallbackProductPage(page: nextPage)
            currentPage = response.page
            hasMoreProducts = response.hasMorePages
            products.append(contentsOf: response.items)
        } else {
            do {
                let response = try await service.fetchProducts(page: nextPage, pageSize: pageSize)
                currentPage = response.page
                hasMoreProducts = response.hasMorePages
                products.append(contentsOf: response.items)
            } catch {
                productErrorMessage = error.localizedDescription
            }
        }

        isLoadingNextPage = false
    }

    private func fallbackProductPage(page: Int) -> ProductPage {
        let allProducts = Product.sampleProducts
        let startIndex = max(0, (page - 1) * pageSize)
        guard startIndex < allProducts.count else {
            return ProductPage(items: [], page: page, hasMorePages: false)
        }

        let endIndex = min(allProducts.count, startIndex + pageSize)
        return ProductPage(
            items: Array(allProducts[startIndex..<endIndex]),
            page: page,
            hasMorePages: endIndex < allProducts.count
        )
    }
}
