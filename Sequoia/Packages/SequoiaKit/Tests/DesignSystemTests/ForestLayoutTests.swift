import Testing
@testable import DesignSystem

struct ForestLayoutTests {
    @Test(arguments: [0, 1, 3, 4, 10, 100, ForestLayout.maxVisibleTrees, 500])
    func placesEveryVisibleTreeOnce(planted: Int) {
        let layout = ForestLayout(planted: planted)
        let expected = min(planted, ForestLayout.maxVisibleTrees)
        #expect(layout.placements.count == expected)
        #expect(Set(layout.placements.map(\.index)).count == expected)
    }

    @Test func newestTreesStandNearest() {
        let layout = ForestLayout(planted: 40)
        let near = layout.placements.filter { $0.layer == .near }.map(\.index)
        #expect(Set(near) == [39, 38, 37])
        let oldestLayer = layout.placements.first { $0.index == 0 }?.layer
        #expect(oldestLayer == .horizon)
    }

    @Test func isDeterministic() {
        #expect(ForestLayout(planted: 57) == ForestLayout(planted: 57))
    }

    @Test func treesStayWithinTheScene() {
        for placement in ForestLayout(planted: 150).placements {
            #expect(placement.x > -0.05 && placement.x < 1.05)
        }
    }

    @Test func nearTreesLeaveRoomForTheCurrentTree() {
        for placement in ForestLayout(planted: 3).placements {
            #expect(abs(placement.x - ForestLayout.currentTreeX) > 0.2)
        }
    }

    @Test func drawsBackToFront() {
        let layers = ForestLayout(planted: 80).placements.map(\.layer)
        #expect(layers == layers.sorted())
    }
}
