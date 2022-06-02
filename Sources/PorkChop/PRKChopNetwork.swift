import Foundation
import Combine

public class PRKChopNetworking {
    public var session: URLSession = URLSession(configuration: .default)
    
    public var configuration: URLSessionConfiguration = {
        var config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        return config
    }()
    
    public var subscriptions: Set<AnyCancellable> = []
    
    public var debugModeEnabled: Bool = false
    
    private var sessionToken: PRKChopToken?
    /* Caching policy applied to all requests for the instance of the class, default is to ignore all cache on device and on server.*/
    private var cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    /* Time in seconds the request will wait for a response before timing out */
    private var defaultTimeout: Int = 30
    
    public convenience init(with token: PRKChopToken, cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData, defaultTimeout: Int = 30, debugMode: Bool = false) {
        self.init()
        self.sessionToken = token
        // determine the token type
        switch token {
        case let t as PRKChopAuthToken:
            self.configuration.httpAdditionalHeaders = t.headerToken
        default: break
        }
        self.cachePolicy = cachePolicy
        self.defaultTimeout = defaultTimeout
        self.session = URLSession(configuration: self.configuration)
        self.debugModeEnabled = debugMode
    }
    
    public init() { }
    
    public func make<T: Encodable>(for url: String, httpMethod: HTTPRequestType, body: T, query: [URLQueryItem]? = nil, completion: @escaping (_ result: Result<Data, Error>) -> Void) throws {
        do {
            let request = try composeRequest(for: url, httpMethod: httpMethod, body: body, query: query)
            let publisher = createPublisherRequest(url: request)
            consumeRequest(request: publisher, completion: completion)
        } catch let err {
            throw err
        }
        
    }
    
    public func make<T: Encodable>(for url: String, httpMethod: HTTPRequestType, body: T, query: [URLQueryItem]? = nil) async -> Data? {
        do {
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) -> Void in
                do {
                    let request = try composeRequest(for: url, httpMethod: httpMethod, body: body, query: query)
                    let publisher = createPublisherRequest(url: request)
                    consumeRequest(request: publisher, completion: { result in
                        switch result {
                        case .success(let data):
                            continuation.resume(returning: data)
                        case .failure(let err):
                            continuation.resume(with: .failure(err))
                        }
                        
                    })
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
        } catch {
            return nil
        }
    }
    
    public func createRequest<T: Encodable>(url: URL, httpMethod: HTTPRequestType, body: T = PRKChopEmptyBody() as! T, query: [URLQueryItem]) -> URLRequest {
        var r = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        r.queryItems = query
        // check to add an api token
        if let t = sessionToken as? PRKChopAPIToken {
            r.queryItems?.append(t.queryItem)
        }
        var request = URLRequest(url: r.url!)
        request.httpMethod = httpMethod.rawValue
        return request
    }
    
    public func createRequest<T: Encodable>(url: URL, httpMethod: HTTPRequestType, body: T = PRKChopEmptyBody() as! T) -> URLRequest {
        
        var r = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if let t = sessionToken as? PRKChopAPIToken {
            r.queryItems = []
            r.queryItems?.append(t.queryItem)
        }
        var request = URLRequest(url: r.url!, cachePolicy: cachePolicy, timeoutInterval: TimeInterval(defaultTimeout))
        request.httpMethod = httpMethod.rawValue
        switch httpMethod {
        case .post, .put, .patch:
            request.httpBody = try? JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        default: break
        }
        return request
    }
    
    public func createPublisherRequest(url: URLRequest) -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure> {
        return session.dataTaskPublisher(for: url).eraseToAnyPublisher()
    }
    
    /**
     Creates a data task publisher for a given url URLRequest.  Provides the ability to override the default http status code error handling in case API returns non-traditional error messaging or status codes.
     For example, some servers return HTTP Status 200 even for requests that fail.  httpErrorStatusHandler would allow handling those types of situations.
     */
    public func createPublisherRequest(url: URLRequest, httpErrorStatusHandler: ((Int) throws -> Void)? = nil) -> AnyPublisher<Data, Error> {
        return session
            .dataTaskPublisher(for: url)
            .receive(on: DispatchQueue.main)
            .tryMap { [weak self] r -> Data in
                guard let response = r.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                self?.printDebug(output: r)
                /// has provided httpErrorStatusHandler?
                if httpErrorStatusHandler != nil {
                    do {
                        try httpErrorStatusHandler!(response.statusCode)
                        return r.data
                    } catch let e {
                        throw e
                    }
                } else {
                    /// no provided status handler, invoke default provider.
                    do {
                        try self?.handleHTTPResponse(with: response.statusCode)
                        return r.data
                    } catch let e {
                        throw e
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func consumeRequest(request: AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure>,
                               completion: @escaping ( _ result: Result<Data, Error>) -> Void) {
        request
            .receive(on: DispatchQueue.main)
            .tryMap() { [weak self] e -> Data in
                guard let httpResponse = e.response as? HTTPURLResponse else { throw NetworkErrorType.invalidResponse }
                self?.printDebug(output: e)
                switch httpResponse.statusCode {
                    // handle 2xx type
                    case 200...299: break
                    // handle 4xx type
                    case 401: throw NetworkErrorType.unauthorized
                    case 403: throw NetworkErrorType.forbidden
                    case 404: throw NetworkErrorType.notFound
                    // handle 5xx type
                    case 500...599:
                        throw NetworkErrorType.serverError
                    default:
                        throw NetworkErrorType.unknown
                }
                return e.data
            }
            .sink(receiveCompletion: {
                switch $0 {
                    case .failure(let err): completion(.failure(err))
                    case .finished: break
                }
            }, receiveValue: {
                completion(.success($0))
            })
            .store(in: &subscriptions)
    }
    /**
     Default handler for http responses.  Handles standard responses like 200 - 299 and throws specific network errors for other status codes.
     */
    internal func handleHTTPResponse(with responseCode: Int) throws {
        switch responseCode {
            // handle 2xx type
            case 200...299: break
            // handle 4xx type
            case 401: throw NetworkErrorType.unauthorized
            case 403: throw NetworkErrorType.forbidden
            case 404: throw NetworkErrorType.notFound
            // handle 5xx type
            case 500...599:
                throw NetworkErrorType.serverError
            default:
                throw NetworkErrorType.unknown
        }
    }
    
    internal func printDebug(output: URLSession.DataTaskPublisher.Output) {
        if debugModeEnabled {
            print("==== Response ====")
            print(output)
            print(output.response.url?.absoluteString ?? "")
            print("==== Response Body ====")
            print(output.data.prettyPrintJSON ?? "No JSON Body")
        }
    }
    
    internal func composeRequest<T: Encodable>(for url: String, httpMethod: HTTPRequestType, body: T?, query: [URLQueryItem]? = nil) throws -> URLRequest {
        // tricky to deal with since URL can take "invalid" URLs and still give you a non-nil value.
        // just for sanity sake, we check if the value is nil and throw if it is.
        guard let url = URL(string: url) else {
            throw NetworkErrorType.invalidURL
        }
        var request: URLRequest!
        if query != nil {
            request = createRequest(url: url, httpMethod: httpMethod, body: body, query: query!)
        } else {
            request = createRequest(url: url, httpMethod: httpMethod, body: body)
        }
        switch httpMethod {
            case .post, .put, .patch:
                request.httpBody = try? JSONEncoder().encode(body)
            default: break
        }
        if debugModeEnabled {
            print("==== Request ====")
            print("\(httpMethod.rawValue) - \(request.url?.absoluteString ?? "No URL Available")")
            print("==== Request Headers ====")
            print(request.allHTTPHeaderFields ?? [:])
            print("==== Configuration Headers ====")
            print(self.session.configuration.httpAdditionalHeaders ?? "")
            print("==== Request Body ====")
            print(request.httpBody?.prettyPrintJSON ?? "No JSON given")
        }
        return request
    }
}

public enum HTTPRequestType: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public enum NetworkErrorType: Error, LocalizedError {
    case badStatus(status: Int)
    case invalidResponse
    case unauthorized
    case forbidden
    case unknown
    case serverError
    case notFound
    case invalidURL
    case tooManyRetryAttemps
    var localizedDescription: String {
        switch self {
            case .badStatus(let status): return "Status was \(status)"
            case .invalidResponse: return "The server returned with a bad response."
            case .unauthorized: return "Authentication is required to access this resource."
            case .forbidden: return "User does not have proper permission to access this resource."
            case .unknown: return "The server returned an unknown error."
            case .serverError: return "The server returned an error."
            case .notFound: return "The requested resource does not exist."
            case .invalidURL: return "URL is malformed."
            case .tooManyRetryAttemps: return "Request was retried too many times."
        }
    }
    public var errorDescription: String? { return localizedDescription }
}

