import Foundation
import Testing
@testable import SubsKun

struct ExchangeRateSnapshotTests {
    @Test
    func convertsFromUSDToJPY() {
        let snapshot = makeSnapshot()

        let converted = snapshot.convert(amount: 20, from: "USD", to: "JPY")
        #expect(converted == 3000)
    }

    @Test
    func convertsFromEURToJPY() {
        let snapshot = makeSnapshot()

        let converted = snapshot.convert(amount: 20, from: "EUR", to: "JPY")
        #expect(converted == 3750)
    }

    @Test
    func returnsNilWhenRateIsMissing() {
        let snapshot = makeSnapshot()

        let converted = snapshot.convert(amount: 100, from: "XXX", to: "JPY")
        #expect(converted == nil)
    }

    @Test
    func returnsExchangeRateForOneUnit() {
        let snapshot = makeSnapshot()

        let usdToJPY = snapshot.rate(from: "USD", to: "JPY")
        let eurToJPY = snapshot.rate(from: "EUR", to: "JPY")

        #expect(usdToJPY == 150)
        #expect(eurToJPY == 187.5)
    }

    private func makeSnapshot() -> ExchangeRateSnapshot {
        ExchangeRateSnapshot(
            baseCode: "USD",
            rates: [
                "USD": 1,
                "JPY": 150,
                "EUR": 0.8
            ],
            lastUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            nextUpdateAt: Date(timeIntervalSince1970: 1_700_086_400)
        )
    }
}
