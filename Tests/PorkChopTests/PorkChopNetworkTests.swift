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
    override func setUp() {
        super.setUp()
        sut = PRKChopNetworking()
        mockPublisher = PassthroughSubject<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure>().eraseToAnyPublisher()
        givenURLRequest = URLRequest(url: givenMockURL)
        sut.session = createMockSession()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Network HTTP Status Code Tests
    
    func test_handle200StatusCodeWithData() {
        // given
        let exp = expectation(description: "handle 200 status code with data")
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, self.sampleData())
        }
        
        // when
        let req = sut.createPublisherRequest(url: givenURLRequest)
        sut.consumeRequest(request: req, completion: { result in
            switch result {
            case .success(let data):
                XCTAssertGreaterThan(data.count, 0)
            case .failure(let err):
                XCTFail(err.localizedDescription)
            }
            exp.fulfill()
        })
        
        // then
        wait(for: [exp], timeout: 1)
    }
    
    func test_handles401StatusCode() {
        // given
        let exp = expectation(description: "wait for completion")
        let expectedError = NetworkErrorType.unauthorized
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // when
        let req = sut.createPublisherRequest(url: givenURLRequest)
        
        // then
        sut.consumeRequest(request: req, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Was not expecting data")
            case .failure(let err):
                print(err)
                XCTAssertEqual((err as? NetworkErrorType)?.errorDescription, expectedError.errorDescription)
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 1)
    }
    
    func test_handles403StatusCode() {
        // given
        let exp = expectation(description: "wait for completion")
        let expectedError = NetworkErrorType.forbidden
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // when
        let req = sut.createPublisherRequest(url: givenURLRequest)
        
        // then
        sut.consumeRequest(request: req, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Was not expecting data")
            case .failure(let err):
                print(err)
                XCTAssertEqual((err as? NetworkErrorType)?.errorDescription, expectedError.errorDescription)
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 1)
    }
    
    func test_handles404StatusCode() {
        // given
        let exp = expectation(description: "wait for completion")
        let expectedError = NetworkErrorType.notFound
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // when
        let req = sut.createPublisherRequest(url: givenURLRequest)
        
        // then
        sut.consumeRequest(request: req, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Was not expecting data")
            case .failure(let err):
                print(err)
                XCTAssertEqual((err as? NetworkErrorType)?.errorDescription, expectedError.errorDescription)
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 1)
    }
    
    func test_handles5xxStatusCode() {
        // given
        let exp = expectation(description: "wait for completion")
        let expectedError = NetworkErrorType.serverError
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // when
        let req = sut.createPublisherRequest(url: givenURLRequest)
        
        // then
        sut.consumeRequest(request: req, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Was not expecting data")
            case .failure(let err):
                print(err)
                XCTAssertEqual((err as? NetworkErrorType)?.errorDescription, expectedError.errorDescription)
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 1)
    }
    
    func test_handlesDefaultAndOutofBoundsStatusCode() {
        // given
        let exp = expectation(description: "wait for completion")
        let expectedError = NetworkErrorType.unknown
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 600, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // when
        let req = sut.createPublisherRequest(url: givenURLRequest)
        
        // then
        sut.consumeRequest(request: req, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Was not expecting data")
            case .failure(let err):
                XCTAssertEqual((err as? NetworkErrorType)?.errorDescription, expectedError.errorDescription)
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: 1)
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
        sut = PRKChopNetworking(with: PRCKChopDefaultAuthenticationToken(expirationDate: expDate, token: givenToken, tokenType: givenTokenType))

        // when
        let result = sut.configuration.httpAdditionalHeaders as? [String:String]
        
        // then
        XCTAssertEqual(result?["Authorization"], expectedTokenStructure)
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
    }
    
    // MARK: - Make network request tests
    
    func test_givenValidURL_doesNotThrowURLException() {
        // given
        let givenValidURL = givenMockURL.absoluteString
        
        // then
        do {
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(url: self.givenMockURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            try sut.make(for: givenValidURL, httpMethod: .get, body: PRKChopEmptyBody(), completion: { _ in })
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

