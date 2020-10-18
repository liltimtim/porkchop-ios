import Foundation

protocol PRKChopAuthToken: Encodable, Decodable {
    var token: String { get set }
    var tokenType: String { get set }
    var expirationDate: String { get set }
    var headerToken: [String:String] { get }
    func isExpired(_ date: Date) -> Bool
    /**
     Internally parses and attempts to give the expiration date as a Date object based on the expirationDate string property.
     Assumes that the expiration date string is in ISO8601 format.
     */
    func expDate() -> Date?
}

public struct PRCKChopDefaultAuthenticationToken: PRKChopAuthToken {
    /** Assumes an ISO8601 Date String */
    var expirationDate: String
    var token: String
    var tokenType: String
    /** Computes the proper HTTP Header for Authorization in the form of "Authorization" : <auth_type> <token> */
    var headerToken: [String:String] { return ["Authorization": "\(tokenType) \(token)"] }
    
    /**
     Determines if the token has exceeded the expiration date of the token lifespan. Compares the incoming date has not exceeded the expiration date.
     
     - Parameter date: Date object that will be compared against the expiration date property
     */
    func isExpired(_ date: Date) -> Bool {
        let dateFormatter = ISO8601DateFormatter()
        let expDate = dateFormatter.date(from: expirationDate)!
        return date > expDate
    }
    
    func expDate() -> Date? {
        return parseDate()
    }
    
    private func parseDate() -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: expirationDate)
    }
}

