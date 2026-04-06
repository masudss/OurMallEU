import Foundation
import Testing
@testable import OurMallEU

@Suite("Product Models")
@MainActor
struct ProductModelTests {
    @Test("Default selection uses the first available option values")
    func defaultSelectionUsesFirstAvailableOptionValues() {
        let product = TestFactory.product(
            options: [
                ProductOption(name: "size", values: ["S", "M", "L"]),
                ProductOption(name: "color", values: ["Red", "Black"])
            ]
        )

        #expect(product.defaultSelection.quantity == 1)
        #expect(product.defaultSelection.selectedOptions["size"] == "S")
        #expect(product.defaultSelection.selectedOptions["color"] == "Red")
    }

    @Test("Discounted price and stock are derived from source values")
    func discountedPriceAndStockAreDerivedFromSourceValues() {
        let product = TestFactory.product(price: 240, discountPercentage: 10, quantityRemaining: 0)

        #expect(product.discountedPrice == Decimal(216))
        #expect(product.inStock == false)
    }

    @Test("DTO mapping applies option sorting and pending fallback status")
    func dtoMappingAppliesOptionSortingAndPendingFallbackStatus() {
        let data = """
        {
          "id": "dto-1",
          "name": "Mapped Product",
          "category": ["electronics", "audio"],
          "imageURL": null,
          "vendor": { "id": "vendor-1", "name": "Vendor One" },
          "price": 90,
          "discountPercentage": 5,
          "offerEndsAt": null,
          "quantityRemaining": 7,
          "summary": null,
          "options": [
            { "name": "size", "values": ["S", "M"] },
            { "name": "color", "values": ["Black"] }
          ],
          "status": "PENDING"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try! decoder.decode(ProductDTO.self, from: data)

        let product = dto.toProduct()

        #expect(product.status == .pending)
        #expect(product.category == ["electronics", "audio"])
        #expect(product.summary.contains("premium multi-vendor"))
        #expect(product.options.map(\.name) == ["color", "size"])
    }
}
