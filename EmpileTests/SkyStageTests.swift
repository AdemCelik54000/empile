import Testing
@testable import Empile

@Suite("The sky changes color as the score climbs")
struct SkyStageTests {
    @Test func startingSkyUntilTheFirstStep() {
        #expect(SkyStage.index(forScore: 0, step: 2500, count: 5) == 0)
        #expect(SkyStage.index(forScore: 2499, step: 2500, count: 5) == 0)
    }

    @Test func newSkyAtEachStep() {
        #expect(SkyStage.index(forScore: 2500, step: 2500, count: 5) == 1)
        #expect(SkyStage.index(forScore: 5000, step: 2500, count: 5) == 2)
        #expect(SkyStage.index(forScore: 10_000, step: 2500, count: 5) == 4)
    }

    @Test func cyclesWithoutComingBackToTheStartingSky() {
        #expect(SkyStage.index(forScore: 12_500, step: 2500, count: 5) == 1)
        #expect(SkyStage.index(forScore: 22_500, step: 2500, count: 5) == 1)
    }
}
