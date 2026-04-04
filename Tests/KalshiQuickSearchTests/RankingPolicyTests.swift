import Foundation
import Testing
@testable import KalshiQuickSearchApp

struct RankingPolicyTests {
    @Test
    func titleMatchOutranksDescriptionOnlyMatch() async throws {
        let policy = RankingPolicy()
        let titleCandidate = IndexedSearchCandidate(
            market: makeMarket(
                ticker: "TITLE1",
                title: "Will Kash Patel be FBI Director?",
                description: "Election market",
                volume24h: 150_000
            ),
            baseRank: 0
        )
        let descriptionCandidate = IndexedSearchCandidate(
            market: makeMarket(
                ticker: "DESC1",
                title: "Who leaves office first?",
                description: "This market mentions Kash Patel in the rules body.",
                volume24h: 150_000
            ),
            baseRank: 0
        )

        let ranked = policy.rank(query: "kash patel", candidates: [descriptionCandidate, titleCandidate])
        #expect(ranked.first?.market.ticker == "TITLE1")
    }

    @Test
    func outcomeMatchCanBeatWeakerTitleMatch() async throws {
        let policy = RankingPolicy()
        let titleCandidate = IndexedSearchCandidate(
            market: makeMarket(
                ticker: "TITLE2",
                title: "Will the Fed cut rates in June?",
                yesLabel: "Cut happens",
                noLabel: "No cut",
                volume24h: 90_000
            ),
            baseRank: 0
        )
        let outcomeCandidate = IndexedSearchCandidate(
            market: makeMarket(
                ticker: "OUTCOME1",
                title: "What happens with the Fed?",
                yesLabel: "25 bps cut",
                noLabel: "No cut",
                volume24h: 80_000
            ),
            baseRank: 0
        )

        let ranked = policy.rank(query: "25 bps cut", candidates: [titleCandidate, outcomeCandidate])
        #expect(ranked.first?.market.ticker == "OUTCOME1")
    }

    @Test
    func liquidityBreaksCloseTextTies() async throws {
        let policy = RankingPolicy()
        let lowerVolume = IndexedSearchCandidate(
            market: makeMarket(
                ticker: "LOWVOL",
                title: "Will Bitcoin be above 100k?",
                description: "BTC market",
                volume24h: 2_000
            ),
            baseRank: 0
        )
        let higherVolume = IndexedSearchCandidate(
            market: makeMarket(
                ticker: "HIGHVOL",
                title: "Will Bitcoin be above 100k?",
                description: "BTC market",
                volume24h: 150_000
            ),
            baseRank: 0
        )

        let ranked = policy.rank(query: "bitcoin 100k", candidates: [lowerVolume, higherVolume])
        #expect(ranked.first?.market.ticker == "HIGHVOL")
    }

    private func makeMarket(
        ticker: String,
        title: String,
        description: String? = nil,
        yesLabel: String? = "YES",
        noLabel: String? = "NO",
        volume24h: Double? = nil
    ) -> MarketSummary {
        MarketSummary(
            ticker: ticker,
            eventTicker: "EVENT",
            seriesTicker: "SERIES",
            title: title,
            subtitle: nil,
            yesLabel: yesLabel,
            noLabel: noLabel,
            eventTitle: nil,
            eventSubtitle: nil,
            description: description,
            category: "Politics",
            status: "open",
            lastPrice: 0.52,
            yesPrice: 0.52,
            noPrice: 0.48,
            volume: volume24h,
            volume24h: volume24h,
            openInterest: volume24h,
            liquidity: volume24h,
            updatedAt: Date(),
            openTime: nil,
            closeTime: nil,
            imageURL: nil,
            webURL: nil
        )
    }
}
