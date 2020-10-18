import Foundation
import Combine

@available(iOS 13.0, *)
@available(macOS 10.15, *)
class PRKChopNetworking {
    var session: URLSession = URLSession(configuration: .default)
    
    var configuration: URLSessionConfiguration = {
        var config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        return config
    }()
    
    var subscriptions: Set<AnyCancellable> = []
    
    private var sessionToken: PRKChopAuthToken?
    /* Caching policy applied to all requests for the instance of the class, default is to ignore all cache on device and on server.*/
    private var cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    /* Time in seconds the request will wait for a response before timing out */
    private var defaultTimeout: Int = 30
    
    convenience init(with token: PRKChopAuthToken, cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData, defaultTimeout: Int = 30) {
        self.init()
        self.sessionToken = token
        self.configuration.httpAdditionalHeaders = token.headerToken
        self.cachePolicy = cachePolicy
        self.defaultTimeout = defaultTimeout
    }
    
    func make<T: Encodable>(for url: String, httpMethod: HTTPRequestType, body: T, completion: @escaping (_ result: Result<Data, Error>) -> Void) throws {
        // tricky to deal with since URL can take "invalid" URLs and still give you a non-nil value.
        // just for sanity sake, we check if the value is nil and throw if it is.
        guard let url = URL(string: url) else {
            throw NetworkErrorType.invalidURL
        }
        let request = createRequest(url: url, httpMethod: httpMethod, body: body)
        let publisher = createPublisherRequest(url: request)
        consumeRequest(request: publisher, completion: completion)
    }
    
    func createRequest<T: Encodable>(url: URL, httpMethod: HTTPRequestType, body: T = PRKChopEmptyBody() as! T) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: TimeInterval(defaultTimeout))
        request.httpMethod = httpMethod.rawValue
        switch httpMethod {
        case .post, .put, .patch:
            request.httpBody = try? JSONEncoder().encode(body)
        default: break
        }
        return request
    }
    
    func createPublisherRequest(url: URLRequest) -> AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure> {
        return session.dataTaskPublisher(for: url).eraseToAnyPublisher()
    }
    
    func consumeRequest(request: AnyPublisher<URLSession.DataTaskPublisher.Output, URLSession.DataTaskPublisher.Failure>,
                        completion: @escaping ( _ result: Result<Data, Error>) -> Void) {
        request
            .receive(on: DispatchQueue.main)
            .tryMap() { e -> Data in
                guard let httpResponse = e.response as? HTTPURLResponse else { throw NetworkErrorType.invalidResponse }
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

enum HTTPRequestType: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

enum NetworkErrorType: Error, LocalizedError {
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
    var errorDescription: String? { return localizedDescription }
}
