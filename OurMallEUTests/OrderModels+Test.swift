import Foundation
import Testing
@testable import OurMallEU

@Suite("Order Models")
struct OrderModelTests {
    @Test("Item settled state is only delivered or cancelled")
    func itemSettledStateIsOnlyDeliveredOrCancelled() {
        #expect(ItemStatus.pending.isSettled == false)
        #expect(ItemStatus.confirmed.isSettled == false)
        #expect(ItemStatus.shipped.isSettled == false)
        #expect(ItemStatus.delivered.isSettled == true)
        #expect(ItemStatus.cancelled.isSettled == true)
    }

    @Test("Order display title reflects cancelled and delivered states")
    func orderDisplayTitleReflectsCancelledAndDeliveredStates() {
        let cancelledOrder = TestFactory.order(itemStatuses: [.cancelled, .cancelled], orderStatus: .settled)
        let deliveredOrder = TestFactory.order(itemStatuses: [.delivered, .delivered], orderStatus: .settled)

        #expect(cancelledOrder.displayStatusTitle == "Cancelled")
        #expect(deliveredOrder.displayStatusTitle == "Delivered")
    }
}
