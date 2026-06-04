import XCTest
@testable import PlankFood

final class FoodVisionServiceTests: XCTestCase {

    // MARK: - Mock URLProtocol
    //
    // Intercepts URLSession requests and returns canned responses.
    // Lets us snapshot-test the full HTTP path without hitting the
    // real Edge Function.

    final class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var stubbedResponse: (Int, Data)?
        nonisolated(unsafe) static var stubbedError: Error?
        nonisolated(unsafe) static var lastRequest: URLRequest?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.lastRequest = request

            if let stubbedError = Self.stubbedError {
                client?.urlProtocol(self, didFailWithError: stubbedError)
                return
            }

            guard let (status, data) = Self.stubbedResponse else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    // MARK: - Fixtures

    private func makeService(token: String? = "test-jwt") -> FoodVisionService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let config = FoodVisionService.Config(
            supabaseURL: URL(string: "https://test.supabase.co")!,
            anonKey: "sb_publishable_test",
            tokenProvider: { token }
        )

        return FoodVisionService(config: config, session: session)
    }

    override func setUp() {
        super.setUp()
        MockURLProtocol.stubbedResponse = nil
        MockURLProtocol.stubbedError = nil
        MockURLProtocol.lastRequest = nil
    }

    // MARK: - Happy path

    func testSuccessfulScanMapsToCapturedFood() async throws {
        let responseJSON = """
        {
            "items": [
                {
                    "name": "matcha latte",
                    "usda_search_terms": ["matcha latte", "green tea latte"],
                    "preparation": "raw",
                    "cuisine_hint": "japanese",
                    "portion_grams": 350,
                    "portion_grams_low": 300,
                    "portion_grams_high": 400,
                    "confidence": 0.92,
                    "notes": "oat milk visible"
                }
            ],
            "plate_type": "single",
            "needs_second_photo": false,
            "second_photo_hint": "",
            "_meta": {
                "cost_usd": 0.003,
                "model": "gpt-5",
                "duration_ms": 2100,
                "scan_id": "abc-123"
            }
        }
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (200, responseJSON)

        let service = makeService()
        let result = try await service.scan(
            imageData: Data([0xFF, 0xD8, 0xFF]),
            cuisineProfile: "japanese, mediterranean",
            mode: .justAte
        )

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].name, "matcha latte")
        XCTAssertEqual(result.items[0].portionGrams, 350)
        XCTAssertEqual(result.items[0].portionGramsLow, 300)
        XCTAssertEqual(result.items[0].portionGramsHigh, 400)
        XCTAssertEqual(result.items[0].confidence, 0.92)
        XCTAssertEqual(result.items[0].notes, "oat milk visible")
        XCTAssertEqual(result.items[0].usdaSearchTerms, ["matcha latte", "green tea latte"])

        // Nutrition fields nil until W2-T4 USDA join.
        XCTAssertNil(result.items[0].kcal)
        XCTAssertNil(result.items[0].proteinG)
        XCTAssertNil(result.items[0].nutritionSource)

        XCTAssertEqual(result.plateType, .single)
        XCTAssertEqual(result.source, .photo)
        XCTAssertEqual(result.confidence, 0.92)
        XCTAssertFalse(result.needsSecondPhoto)
        XCTAssertNil(result.secondPhotoHint)
    }

    func testRestaurantRangePlateTypeMaps() async throws {
        let responseJSON = """
        {
            "items": [],
            "plate_type": "restaurant_range",
            "needs_second_photo": false,
            "second_photo_hint": ""
        }
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (200, responseJSON)

        let result = try await makeService().scan(
            imageData: Data([0xFF]),
            cuisineProfile: nil,
            mode: .justAte
        )

        XCTAssertEqual(result.plateType, .restaurantRange)
    }

    func testNeedsSecondPhotoSetsHint() async throws {
        let responseJSON = """
        {
            "items": [],
            "plate_type": "bowl",
            "needs_second_photo": true,
            "second_photo_hint": "shoot from 45 degrees to estimate rice depth"
        }
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (200, responseJSON)

        let result = try await makeService().scan(
            imageData: Data([0xFF]),
            cuisineProfile: nil,
            mode: .justAte
        )

        XCTAssertTrue(result.needsSecondPhoto)
        XCTAssertEqual(result.secondPhotoHint, "shoot from 45 degrees to estimate rice depth")
    }

    // MARK: - Request shape

    func testRequestBodyIncludesBase64AndCuisine() async throws {
        let responseJSON = """
        {
            "items": [],
            "plate_type": "single",
            "needs_second_photo": false,
            "second_photo_hint": ""
        }
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (200, responseJSON)

        let imageBytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
        _ = try await makeService().scan(
            imageData: imageBytes,
            cuisineProfile: "korean home-cooked",
            mode: .justAte
        )

        let request = MockURLProtocol.lastRequest!
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://test.supabase.co/functions/v1/food-vision"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-jwt")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "sb_publishable_test")

        let bodyStream = request.httpBodyStream!
        let bodyData = Self.readAll(from: bodyStream)
        let decoded = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
        XCTAssertEqual(decoded["cuisine_profile"] as? String, "korean home-cooked")
        XCTAssertEqual(decoded["image_base64"] as? String, imageBytes.base64EncodedString())
    }

    // MARK: - Errors

    func testNotAuthenticatedWhenNoToken() async {
        let service = makeService(token: nil)
        do {
            _ = try await service.scan(
                imageData: Data([0xFF]),
                cuisineProfile: nil,
                mode: .justAte
            )
            XCTFail("expected notAuthenticated")
        } catch VisionError.notAuthenticated {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRateLimitedMappedFrom429PerUserCode() async {
        let body = """
        {"error":"rate_limited","code":"PER_USER_LIMIT","copy":"give us a few hours — you've scanned a lot today."}
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (429, body)

        do {
            _ = try await makeService().scan(
                imageData: Data([0xFF]),
                cuisineProfile: nil,
                mode: .justAte
            )
            XCTFail("expected rateLimited")
        } catch VisionError.rateLimited(let copy) {
            XCTAssertTrue(copy.contains("scanned a lot today"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testBudgetCappedMappedFrom429DailyBudgetCode() async {
        let body = """
        {"error":"budget_cap","code":"DAILY_BUDGET","copy":"give us a few hours — we're catching our breath."}
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (429, body)

        do {
            _ = try await makeService().scan(
                imageData: Data([0xFF]),
                cuisineProfile: nil,
                mode: .justAte
            )
            XCTFail("expected budgetCapped")
        } catch VisionError.budgetCapped(let copy) {
            XCTAssertTrue(copy.contains("catching our breath"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testInvalidRequestFrom400() async {
        let body = """
        {"error":"missing_image"}
        """.data(using: .utf8)!
        MockURLProtocol.stubbedResponse = (400, body)

        do {
            _ = try await makeService().scan(
                imageData: Data([0xFF]),
                cuisineProfile: nil,
                mode: .justAte
            )
            XCTFail("expected invalidRequest")
        } catch VisionError.invalidRequest {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testNetworkErrorWrapsURLError() async {
        MockURLProtocol.stubbedError = URLError(.notConnectedToInternet)

        do {
            _ = try await makeService().scan(
                imageData: Data([0xFF]),
                cuisineProfile: nil,
                mode: .justAte
            )
            XCTFail("expected networkError")
        } catch VisionError.networkError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - User-facing copy

    func testUserFacingCopyPullsFromEdgeFunction() {
        let copy = "give us a few hours — you've scanned a lot today."
        let err = VisionError.rateLimited(copy: copy)
        XCTAssertEqual(err.userFacingCopy, copy)
    }

    func testUserFacingCopyForNotAuthenticated() {
        XCTAssertTrue(VisionError.notAuthenticated.userFacingCopy.contains("sign in"))
    }

    // MARK: - Helpers

    private static func readAll(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: bufferSize)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}
