import CoreGraphics
import FuwaCore
import Testing

struct FloatingControlsLayoutTests {
    @Test func controlsStayInsideEveryDisplayArrangement() {
        let displays = [
            CGRect(x: 0, y: 80, width: 1512, height: 869),
            CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            CGRect(x: 100, y: 982, width: 1280, height: 800),
            CGRect(x: 1512, y: -500, width: 1440, height: 900)
        ]
        for display in displays {
            for x in [display.minX - 200, display.minX, display.midX, display.maxX - 50, display.maxX + 200] {
                for y in [display.minY - 200, display.minY, display.midY, display.maxY - 50, display.maxY + 200] {
                    let result = FloatingControlsLayout.frame(source: CGRect(x: x, y: y, width: 600, height: 400), visible: display)
                    #expect(display.contains(result))
                    #expect(result.size == CGSize(width: 380, height: 78))
                }
            }
        }
    }

    @Test func screenSelectionUsesOverlapAndThenNearestDisplay() {
        let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: -1920, y: 0, width: 1920, height: 1080)]
        #expect(FloatingControlsLayout.screenIndex(source: CGRect(x: -1600, y: 100, width: 800, height: 600), screens: screens) == 1)
        #expect(FloatingControlsLayout.screenIndex(source: CGRect(x: -100, y: 100, width: 800, height: 600), screens: screens) == 0)
        #expect(FloatingControlsLayout.screenIndex(source: CGRect(x: -3000, y: 100, width: 600, height: 400), screens: screens) == 1)
        #expect(FloatingControlsLayout.screenIndex(source: .zero, screens: []) == nil)
    }
}
