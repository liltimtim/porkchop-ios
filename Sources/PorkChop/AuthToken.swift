import Foundation

/**
 Base conforming protocol for all PRKChopToken types
 */
public protocol PRKChopToken: Encodable, Decodable { }

/**
 Protocol defining authentication with an API that requires URL query parameter based authentication
 */
public protocol PRKChopAPIToken: PRKChopToken {
    var key: String { get set }
    var value: String { get set }
    var queryItem: URLQueryItem { get }
}

/**
Protocol defining authentication type tokens
 
Example Usage for Bearer type authentication token.  This is a common JWT token usage for APIs that authenticate using JWT header tokens.
    
    Header: Token based
    Authorization: bearer <the_token>
 */
public protocol PRKChopAuthToken: PRKChopToken {
    var token: String { get set }
    var tokenType: String { get set }
    var expirationDate: String { get set }
    var headerToken: [String:String] { get }
    var refreshToken: String? { get set }
    func isExpired(_ date: Date) -> Bool
    /**
     Internally parses and attempts to give the expiration date as a Date object based on the expirationDate string property.
     Assumes that the expiration date string is in ISO8601 format.
     */
    func expDate() -> Date?
}

public struct PRKChopRefreshToken: PRKChopToken {
    var refreshToken: String
}

public struct PRKChopDefaultQueryAPIToken: PRKChopAPIToken {
    public var key: String
    public var value: String
    public var queryItem: URLQueryItem { return URLQueryItem(name: key, value: value) }
    public init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }
}

public struct PRCKChopDefaultAuthenticationToken: PRKChopAuthToken {
    public var refreshToken: String?
    
    /** Assumes an ISO8601 Date String */
    public var expirationDate: String
    public var token: String
    public var tokenType: String

    /** Computes the proper HTTP Header for Authorization in the form of "Authorization" : <auth_type> <token> */
    public var headerToken: [String:String] { return ["Authorization": "\(tokenType) \(token)"] }
    
    public enum TokenToleranceLevel {
        case months
        case days
        case hours
        case minutes
        case seconds
    }
    
    public init(expDate: String, token: String, tokenType: String, refreshToken: String? = nil) {
        self.expirationDate = expDate
        self.token = token
        self.tokenType = tokenType
        self.refreshToken = refreshToken
    }
    /**
     Determines if the token has exceeded the expiration date of the token lifespan. Compares the incoming date has not exceeded the expiration date.
     
     - Parameter date: Date object that will be compared against the expiration date property
     */
    public func isExpired(_ date: Date) -> Bool {
        let dateFormatter = ISO8601DateFormatter()
        let expDate = dateFormatter.date(from: expirationDate)!
        return date > expDate
    }
    
    public func expDate() -> Date? {
        return parseDate()
    }
    /**
     Given a reference date, compares the expiration date of the token to the given date and
     determines if the given tolerance is coming close to expiring based on the tolerance level.
     We do not use DateComponents as this is dependent on the type of Calendar given not strictly
     based on an ISO date.
     
     Example: Date, .hours, 4, would look at the date and see if the token is within 4 hours of
     expiring.
     */
    public func isAboutToExpire(_ date: Date, toleranceLevel: TokenToleranceLevel, tolerance: Double) -> Bool {
        // we don't know when the token is going to expire assume it is about to expire.
        guard let expDate = self.expDate() else { return true }
        // is the incoming date greater than the exp date?
        switch date.compare(expDate) {
            case .orderedAscending, .orderedSame:
                break
            case .orderedDescending:
                return true
        }
        var diff: Double
        switch toleranceLevel {
            case .days:
                diff = date.timeIntervalSince(expDate).magnitude / 60.0 / 60.0 / 24.0
            case .hours:
                // convert seconds to hours 60 seconds -> minutes / 60 -> hours
                diff = date.timeIntervalSince(expDate).magnitude / 60.0 / 60.0
            case .minutes:
                diff = date.timeIntervalSince(expDate).magnitude / 60.0
            case .seconds:
                diff = date.timeIntervalSince(expDate).magnitude
            default: return true
        }
        let actualDiff = diff - tolerance
        if actualDiff < 0 { return true }
        return actualDiff <= tolerance
    }
    
    private func parseDate() -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: expirationDate)
    }
}

