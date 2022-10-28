import XCTest
import Combine
@testable import PorkChop

class NetworkingInterfaceTests: XCTestCase {
    var sut: PRKChopNetworking!
    var mockPublisher: AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure>!
    let givenMockURL: URL = URL(string: "http://test.com")!
    var givenURLRequest: URLRequest!
    let givenToken: String = "test_token_123"
    let givenTokenType: String = "bearer"
    private var subscriptions: Set<AnyCancellable> = []
    override func setUp() {
        super.setUp()
        sut = PRKChopNetworking()
        sut.debugModeEnabled = true
        mockPublisher = PassthroughSubject<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure>().eraseToAnyPublisher()
        givenURLRequest = URLRequest(url: givenMockURL)
        sut.session = createMockSession()
    }
    
    override func tearDown() {
        sut = nil
        subscriptions.forEach { $0.cancel() }
        subscriptions = []
        super.tearDown()
    }
    
    func test_make_200_with_make() async {
        // given
        MockURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, self.sampleData())
        }
        // when
        do {
            let request = sut.createRequest(url: "https://test.com",
                                            httpMethod: .get,
                                            body: PRKChopEmptyBody())
            _ = try await sut.make(for: request)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    /// Make a request where the server doesn't return valid JSON data
    func test_make_200_with_post_invalid_response() async {
        MockURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "<html></html>".data(using: .utf8)!)
        }
        // when
        do {
            let request = sut.createRequest(url: "https://test.com",
                                            httpMethod: .post,
                                            body: PRKChopEmptyBody())
            _ = try await sut.make(for: request)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    /// Tests whether we handle cases where we post something but do not care about the response body
    func test_make_200_with_post_empty_response() async {
        MockURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        // when
        do {
            let request = sut.createRequest(url: "https://test.com", httpMethod: .post, body: PRKChopEmptyBody())
            _ = try await sut.make(for: request)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    // MARK: - Network HTTP Async Tests
    func test_make_200_response_with_data() async {
        // given
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, self.sampleData())
        }
        // when
        let request = sut.createRequest(url: self.givenMockURL, httpMethod: .get, body: PRKChopEmptyBody())
        do {
            let result = try await sut.make(for: request)
            // then
            XCTAssertNotNil(result)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test_make_404_response_without_data() async {
        // given
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        let request = sut.createRequest(url: self.givenMockURL, httpMethod: .get, body: PRKChopEmptyBody())
        do {
            _ = try await sut.make(for: request)
            XCTFail("Should not have succeeded")
        } catch {
            XCTAssertEqual(error.localizedDescription, NetworkErrorType.notFound.localizedDescription)
        }
    }
    
    // MARK: - Default HTTP Status Handler
    func test_response_code_200() {
        // given
        let givenResponseCode = 200
        
        // when
        do {
            try sut.handleHTTPResponse(with: givenResponseCode)
        } catch {
            XCTFail("Failed with unexepcted throw: \(error.localizedDescription)")
        }
    }
    
    // MARK: - URL Request Generation Tests
    
    func test_createsValidURLHeaders_withoutSessionToken() {
        // given
        sut = PRKChopNetworking()

        // when
        let result = sut.configuration.httpAdditionalHeaders as? [String:String]
        
        // then
        XCTAssertNil(result?["Authorization"])
    }
    
    func test_createsValidURLHeaders_withSessionToken() {
        // given
        let expDate = UnitTestUtils.createISODate(from: UnitTestUtils.createDate())
        let expectedTokenStructure = "\(givenTokenType) \(givenToken)"
        sut = PRKChopNetworking(with: PRCKChopDefaultAuthenticationToken(expDate: expDate, token: givenToken, tokenType: givenTokenType))

        // when
        let result = sut.configuration.httpAdditionalHeaders as? [String:String]
        
        // then
        XCTAssertEqual(result?["Authorization"], expectedTokenStructure)
    }
    
    func test_createValidURL_withQueryParameters() {
        // given
        let query = [URLQueryItem(name: "test", value: "value")]
        let expectedString = "test=value"
        // when
        let result = sut.createRequest(url: givenMockURL, httpMethod: .post, body: PRKChopEmptyBody(), query: query)
        // then
        XCTAssertNotNil(result.url?.query)
        XCTAssertEqual(result.url?.query, expectedString)
    }
    
    // MARK: - URL Request Creation Tests
    func test_createGETRequest_bodyShouldBeNil() {
        // when
        let result = sut.createRequest(url: givenMockURL, httpMethod: .get, body: PRKChopEmptyBody())
        let expectedHTTPRequestType = "GET"
        // then
        XCTAssertNil(result.httpBody)
        XCTAssertEqual(result.httpMethod, expectedHTTPRequestType)
    }
    
    func test_createPOSTRequest_bodyShouldNotBeNil() {
        // given
        let json = SampleJSONObject()
        
        // when
        let result = sut.createRequest(url: givenMockURL, httpMethod: .post, body: json)
        let body = self.json(from: result.httpBody)
        
        // then
        XCTAssertNotNil(result.httpBody)
        XCTAssertNotNil(body)
        XCTAssertEqual(body, json)
        XCTAssertNil(result.url?.query)
    }
    
    func test_createGETRequest_withAPITokenQueryItem() {
        // given
        let sut = PRKChopNetworking.init(with: PRKChopDefaultQueryAPIToken("apiKey", "apiValue"))
        let expectedQuery = "apiKey=apiValue"
        // when
        let result = sut.createRequest(url: URL(string: "http://test.com")!, httpMethod: .get, body: PRKChopEmptyBody())
        
        // then
        XCTAssertEqual(expectedQuery, result.url?.query)
    }
    
    func test_createGETRequest_withAPIToken_multipleQueryItems() {
        // given
        let sut = PRKChopNetworking.init(with: PRKChopDefaultQueryAPIToken("apiKey", "apiValue"))
        let expectedQuery = "other=value&apiKey=apiValue"
        
        // when
        let result = sut.createRequest(url: URL(string: "http://test.com")!, httpMethod: .get, body: PRKChopEmptyBody(), query: [URLQueryItem(name: "other", value: "value")])
        
        // then
        XCTAssertEqual(expectedQuery, result.url?.query)
    }
    
    func test_createGETRequest_queryShouldNotBeNil() async {
        // given
        let givenQueryItems = [URLQueryItem(name: "test", value: "test_value")]
        
        // then
        do {
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let request = sut.createRequest(url: givenMockURL, httpMethod: .get, body: PRKChopEmptyBody(), query: givenQueryItems)
            _ = try await sut.make(for: request)
        } catch let err {
            XCTFail("Create GET Request with Query threw an unexpected error: \(err.localizedDescription)")
        }
    }
    
    // MARK: - Make network request tests
    
    func test_givenValidURL_doesNotThrowURLException() async {
        // given
        let givenValidURL = givenMockURL.absoluteString
        
        // then
        do {
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let request = sut.createRequest(url: URL(string: givenValidURL)!, httpMethod: .get, body: PRKChopEmptyBody())
            _ = try await sut.make(for: request)
        } catch let err {
            XCTFail("Valid URL threw an unexpected error: \(err.localizedDescription)")
        }
    }
    
    // MARK: - Mock Session
    
    func createMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
    
    // MARK: - Sample JSON Data
    
    func sampleData() -> Data {
        let sampleJSON = """
        [ "data": { } ]
        """
        return sampleJSON.data(using: .utf8) ?? Data()
    }
    
    fileprivate func json(from object: Data?) -> SampleJSONObject? {
        guard let object = object else { return nil }
        return try? JSONDecoder().decode(SampleJSONObject.self, from: object)
    }
    
    fileprivate struct SampleJSONObject: Encodable, Decodable, Equatable {
        var test: String = UUID().uuidString
        
        static func == (lhs: SampleJSONObject, rhs: SampleJSONObject) -> Bool {
            return lhs.test == rhs.test
        }
    }
}

class MockURLProtocol: URLProtocol {
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }
        
        do {
            // 2. Call handler with received request and capture the tuple of response and data.
            let (response, data) = try handler(request)
            
            // 3. Send received response to the client.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            if let data = data {
                // 4. Send received data to the client.
                client?.urlProtocol(self, didLoad: data)
            }
            
            // 5. Notify request has been finished.
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // 6. Notify received error.
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {
        
    }
}

