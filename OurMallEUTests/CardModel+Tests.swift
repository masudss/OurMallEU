import Foundation
import Testing
@testable import OurMallEU

@Suite("Cart Models")
struct CartModelTests {
    @Test("Cart key is stable regardless of option order")
    func cartKeyIsStableRegardlessOfOptionOrder() {
        let item = CartItem(
            product: TestFactory.product(),
            selectedOptions: ["size": "M", "color": "Black"],
            quantity: 2
        )

        #expect(item.cartKey == "product-1::color=Black|size=M")
    }

    @Test("Vendor cart section totals account for discounts")
    func vendorCartSectionTotalsAccountForDiscounts() {
        let vendor = TestFactory.vendor()
        let itemA = CartItem(
            product: TestFactory.product(id: "a", vendor: vendor, price: 100, discountPercentage: 10),
            selectedOptions: [:],
            quantity: 2
        )
        let itemB = CartItem(
            product: TestFactory.product(id: "b", vendor: vendor, price: 50, discountPercentage: 0),
            selectedOptions: [:],
            quantity: 1
        )
        let section = VendorCartSection(vendor: vendor, items: [itemA, itemB], isSelected: true)

        #expect(section.subtotal == Decimal(230))
        #expect(section.listTotal == Decimal(250))
        #expect(section.discountTotal == Decimal(20))
    }

    @Test("Decimal rounding supports VAT calculations")
    func decimalRoundingSupportsVatCalculations() {
        let vat = (Decimal(230) * Decimal.vatRate).rounded()
        #expect(vat == Decimal(string: "17.25"))
    }
}
