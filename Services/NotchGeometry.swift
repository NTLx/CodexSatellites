import AppKit
import CoreGraphics

struct NotchGeometry: Equatable, Sendable {
    let screenFrame: CGRect
    let notchLeftEdge: CGFloat
    let notchRightEdge: CGFloat
    let notchBottomEdge: CGFloat
    let verticalCenter: CGFloat

    var notchCenterX: CGFloat {
        (notchLeftEdge + notchRightEdge) / 2
    }

    static func from(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?,
        horizontalGap: CGFloat
    ) -> NotchGeometry? {
        guard safeAreaTop > 0,
              let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea else {
            return nil
        }

        let leftEdge = leftArea.maxX
        let rightEdge = rightArea.minX
        guard rightEdge > leftEdge, horizontalGap >= 0 else {
            return nil
        }

        let topBand = leftArea.union(rightArea)
        guard topBand.width > 0, topBand.height > 0 else {
            return nil
        }

        return NotchGeometry(
            screenFrame: screenFrame,
            notchLeftEdge: leftEdge,
            notchRightEdge: rightEdge,
            notchBottomEdge: topBand.minY,
            verticalCenter: topBand.midY
        )
    }

    static func from(screen: NSScreen, horizontalGap: CGFloat) -> NotchGeometry? {
        from(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
            horizontalGap: horizontalGap
        )
    }

    func leftAnchor(gap: CGFloat) -> CGFloat {
        notchLeftEdge - gap
    }

    func rightAnchor(gap: CGFloat) -> CGFloat {
        notchRightEdge + gap
    }
}
