import XCTest
@testable import plankAI

// v10.2 — the abdomen band under test: joints place it on the
// shoulder→hip axis; absence falls back to the centered default;
// the crop rect maps Vision space to image space; degenerate input
// never breaks a keep.
final class WaistCropTests: XCTestCase {

    private func standing(
        shoulderY: CGFloat = 0.72, hipY: CGFloat = 0.45, x: CGFloat = 0.5
    ) -> [BodyScanAlignment.Key: BodyScanAlignment.Joint] {
        [
            .leftShoulder: .init(x - 0.08, shoulderY),
            .rightShoulder: .init(x + 0.08, shoulderY),
            .leftHip: .init(x - 0.06, hipY),
            .rightHip: .init(x + 0.06, hipY)
        ]
    }

    func testBandSitsOnTheShoulderHipAxis() throws {
        let band = try XCTUnwrap(WaistCrop.band(from: standing()))
        // axis = 0.27: bottom = 0.45 - 0.0405, top = 0.45 + 0.1674
        XCTAssertEqual(band.bottom, 0.4095, accuracy: 0.001)
        XCTAssertEqual(band.top, 0.6174, accuracy: 0.001)
        XCTAssertEqual(band.centerX, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(band.top, band.bottom)
    }

    func testOffCenterBodyCarriesItsCenter() throws {
        let band = try XCTUnwrap(WaistCrop.band(from: standing(x: 0.62)))
        XCTAssertEqual(band.centerX, 0.62, accuracy: 0.001)
    }

    func testNoJointsMeansNoBand() {
        XCTAssertNil(WaistCrop.band(from: [:]))
    }

    func testHipsAloneMeanNoBand() {
        let hipsOnly: [BodyScanAlignment.Key: BodyScanAlignment.Joint] = [
            .leftHip: .init(0.44, 0.45),
            .rightHip: .init(0.56, 0.45)
        ]
        XCTAssertNil(WaistCrop.band(from: hipsOnly))
    }

    func testLowConfidenceJointsAreIgnored() {
        let ghost: [BodyScanAlignment.Key: BodyScanAlignment.Joint] = [
            .leftShoulder: .init(0.42, 0.72, confidence: 0.1),
            .leftHip: .init(0.44, 0.45, confidence: 0.1)
        ]
        XCTAssertNil(WaistCrop.band(from: ghost))
    }

    func testDegenerateAxisMeansNoBand() {
        // Shoulders at hip height (lying down / garbage detection).
        XCTAssertNil(WaistCrop.band(from: standing(shoulderY: 0.46, hipY: 0.45)))
    }

    func testCropRectMapsVisionToImageSpace() {
        let band = WaistCrop.Band(top: 0.62, bottom: 0.38, centerX: 0.5)
        let rect = WaistCrop.cropRect(for: band, in: CGSize(width: 1080, height: 1440))
        // top 0.62 (bottom-up) → y-down origin at (1-0.62)*1440
        XCTAssertEqual(rect.origin.y, 547.2, accuracy: 0.5)
        XCTAssertEqual(rect.height, 0.24 * 1440, accuracy: 0.5)
        // Centered horizontal window, 2×halfWidth of the frame.
        XCTAssertEqual(rect.width, WaistCrop.halfWidth * 2 * 1080, accuracy: 0.5)
        XCTAssertEqual(rect.origin.x, (0.5 - WaistCrop.halfWidth) * 1080, accuracy: 0.5)
    }

    func testOffCenterCropClampsToTheFrame() {
        let band = WaistCrop.Band(top: 0.62, bottom: 0.38, centerX: 0.95)
        let rect = WaistCrop.cropRect(for: band, in: CGSize(width: 1000, height: 1000))
        XCTAssertLessThanOrEqual(rect.maxX, 1000)
        XCTAssertGreaterThan(rect.width, 0)
    }

    func testDefaultBandIsCentered() {
        let band = WaistCrop.defaultBand
        XCTAssertEqual((band.top + band.bottom) / 2, 0.5, accuracy: 0.001)
        XCTAssertEqual(band.centerX, 0.5, accuracy: 0.001)
    }

    func testCropNeverBreaksAKeep() {
        // A degenerate band returns the original image untouched.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let degenerate = WaistCrop.Band(top: 0.401, bottom: 0.4, centerX: 0.5)
        let out = WaistCrop.image(img, band: degenerate)
        XCTAssertEqual(out.size, img.size)
    }
}
