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
    
    private var sessionToken: PRKChopAuthToken?
    /* Caching policy applied to all requests for the instance of the class, default is to ignore all cache on device and on server.*/
    private var cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    /* Time in seconds the request will wait for a response before timing out */
    private var defaultTimeout: Int = 30
    
    public convenience init(with token: PRKChopAuthToken, cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData, defaultTimeout: Int = 30) {
        self.init()
        self.sessionToken = token
        self.configuration.httpAdditionalHeaders = token.headerToken
        self.cachePolicy = cachePolicy
        self.defaultTimeout = defaultTimeout
        self.session = URLSession(configuration: self.configuration)
    }
    
    public init() { }
    
    public func make<T: Encodable>(for url: String, httpMethod: HTTPRequestType, body: T, query: [URLQueryItem]? = nil, completion: @escaping (_ result: Result<Data, Error>) -> Void) throws {
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
            print("==== Request Body ====")
            print(request.httpBody?.prettyPrintJSON ?? "No JSON given")
        }
        let publisher = createPublisherRequest(url: request)
        consumeRequest(request: publisher, completion: completion)
    }
    
    public func createRequest<T: Encodable>(url: URL, httpMethod: HTTPRequestType, body: T = PRKChopEmptyBody() as! T, query: [URLQueryItem]) -> URLRequest {
        var r = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        r.queryItems = query
        var request = URLRequest(url: r.url!)
        request.httpMethod = httpMethod.rawValue
        return request
    }
    
    public func createRequest<T: Encodable>(url: URL, httpMethod: HTTPRequestType, body: T = PRKChopEmptyBody() as! T) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: TimeInterval(defaultTimeout))
        request.httpMethod = httpMethod.rawValue
        switch httpMethod {
        case .post, .put, .patch:
            request.httpBody = try? JSONEncoder().encode(body)
        default: break
        }
        return request
    }
    
    public func createPublisherRequest(url: URLRequest) -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure> {
        return session.dataTaskPublisher(for: url).eraseToAnyPublisher()
    }
    
    public func consumeRequest(request: AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure>,
                        completion: @escaping ( _ result: Result<Data, Error>) -> Void) {
        request
            .receive(on: DispatchQueue.main)
            .tryMap() { e -> Data in
                guard let httpResponse = e.response as? HTTPURLResponse else { throw NetworkErrorType.invalidResponse }
                if self.debugModeEnabled {
                    print("==== Response ====")
                    print(e)
                    print(e.response.url?.absoluteString ?? "")
                    print("==== Response Body ====")
                    print(e.data.prettyPrintJSON ?? "No JSON Body")
                }
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
        }
    }
    public var errorDescription: String? { return localizedDescription }
}

