import CoreGraphics

/// All inputs use AppKit coordinates, including screens left of or above primary.
public enum FloatingControlsLayout {
    public static func frame(source: CGRect, visible: CGRect, size: CGSize = CGSize(width: 380, height: 78)) -> CGRect {
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)
        let proposedY = source.maxY + height <= visible.maxY ? source.maxY : source.minY - height
        return CGRect(
            x: max(visible.minX, min(source.maxX - width, visible.maxX - width)),
            y: max(visible.minY, min(proposedY, visible.maxY - height)),
            width: width, height: height
        )
    }

    public static func screenIndex(source: CGRect, screens: [CGRect]) -> Int? {
        screens.indices.max { a, b in
            let left = source.intersection(screens[a])
            let right = source.intersection(screens[b])
            let leftArea = left.isNull ? 0 : left.width * left.height
            let rightArea = right.isNull ? 0 : right.width * right.height
            if leftArea != rightArea { return leftArea < rightArea }
            // No overlap (e.g. a disconnected display): choose the nearest screen.
            let leftDistance = distanceSquared(source, screens[a])
            let rightDistance = distanceSquared(source, screens[b])
            return leftDistance > rightDistance
        }
    }

    private static func distanceSquared(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let x = a.midX - b.midX
        let y = a.midY - b.midY
        return x * x + y * y
    }
}
