import CoreGraphics
import XCTest
@testable import CodexSatellites

final class NotchGeometryTests: XCTestCase {
    func testCalculatesEdgesFromAuxiliaryAreas() {
        let geometry = NotchGeometry.from(
            screenFrame: CGRect(x: 0, y: 0, width: 3024, height: 1964),
            safeAreaTop: 74,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 1890, width: 1410, height: 74),
            auxiliaryTopRightArea: CGRect(x: 1614, y: 1890, width: 1410, height: 74),
            horizontalGap: 10
        )

        XCTAssertEqual(geometry?.notchLeftEdge, 1410)
        XCTAssertEqual(geometry?.notchRightEdge, 1614)
        XCTAssertEqual(geometry?.notchCenterX, 1512)
        XCTAssertEqual(geometry?.notchBottomEdge, 1890)
        XCTAssertEqual(geometry?.verticalCenter, 1927)
        XCTAssertEqual(geometry?.leftAnchor(gap: 10), 1400)
        XCTAssertEqual(geometry?.rightAnchor(gap: 10), 1624)
    }

    func testSupportsNonZeroAndNegativeScreenOrigins() {
        let geometry = NotchGeometry.from(
            screenFrame: CGRect(x: -1920, y: 120, width: 1920, height: 1080),
            safeAreaTop: 38,
            auxiliaryTopLeftArea: CGRect(x: -1920, y: 1162, width: 890, height: 38),
            auxiliaryTopRightArea: CGRect(x: -790, y: 1162, width: 790, height: 38),
            horizontalGap: 8
        )

        XCTAssertNotNil(geometry)
        XCTAssertEqual(geometry?.notchLeftEdge, -1030)
        XCTAssertEqual(geometry?.notchRightEdge, -790)
    }

    func testRejectsMissingOrInvalidAreas() {
        XCTAssertNil(NotchGeometry.from(
            screenFrame: .zero,
            safeAreaTop: 0,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            horizontalGap: 10
        ))
        XCTAssertNil(NotchGeometry.from(
            screenFrame: .zero,
            safeAreaTop: 50,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 0, width: 100, height: 50),
            auxiliaryTopRightArea: CGRect(x: 90, y: 0, width: 100, height: 50),
            horizontalGap: 10
        ))
        XCTAssertNil(NotchGeometry.from(
            screenFrame: .zero,
            safeAreaTop: 50,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 0, width: 100, height: 50),
            auxiliaryTopRightArea: CGRect(x: 200, y: 0, width: 100, height: 50),
            horizontalGap: -1
        ))
    }
}
