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
    /// Create a request object with values required to make an HTTP request.
    ///
    /// Supports a HTTP method, optional body to send and query parameters in URL
    public func createRequest<T: Encodable>(url: URL,
                                            httpMethod: HTTPRequestType,
                                            body: T = PRKChopEmptyBody() as! T,
                                            query: [URLQueryItem]) -> URLRequest {
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
    
    public func createRequest<T: Encodable>(url: URL,
                                            httpMethod: HTTPRequestType,
                                            body: T = PRKChopEmptyBody() as! T,
                                            additionalHeaders: [String: String] = [:]) -> URLRequest {
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
        // add any additional headers if present
        for (k, v) in additionalHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }
        return request
    }
    
    public func make(for request: URLRequest) async throws -> Data {
        return try await withCheckedThrowingContinuation { [weak session] continuation in
            
            guard let session = session else {
                continuation.resume(with: .failure(NetworkErrorType.unknown))
                return
            }
            session.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(with: .failure(NetworkErrorType.invalidResponse))
                    return
                }
                guard error == nil else {
                    continuation.resume(with: .failure(error!))
                    return
                }
                do {
                    try self?.handleHTTPResponse(with: response.statusCode)
                    guard let data = data else {
                        continuation.resume(with: .failure(NetworkErrorType.invalidResponse))
                        return
                    }
                    continuation.resume(with: .success(data))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }).resume()
        }
    }
    
    public func updateAuthorizationToken(with newToken: PRKChopAuthToken) {
        self.sessionToken = newToken
        updateConfiguration(with: newToken)
    }
    /// Updates the `URLSessionConfiguration` with a new authentication token.
    ///
    /// This method modifies the `httpAdditionalHeaders` dictionary of the `URLSessionConfiguration`
    /// to include or update the `Authorization` key with the provided token's value.
    ///
    /// - Important: Only instances of `PRKChopAuthToken` will update the authentication header.
    ///   Other token types will be ignored.
    ///
    /// - Parameter token: A `PRKChopToken` instance used to update the session configuration.
    ///   If `token` is of type `PRKChopAuthToken`, its `headerToken` value replaces the current
    ///   `Authorization` header in `httpAdditionalHeaders`.
    ///
    /// - Note: The method does nothing if `token` is not a `PRKChopAuthToken`.
    internal func updateConfiguration(with token: PRKChopToken) {
        // determine the token type
        switch token {
        case let t as PRKChopAuthToken:
            self.configuration.httpAdditionalHeaders = t.headerToken
        default: break
        }
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

