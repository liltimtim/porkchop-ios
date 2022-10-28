import Foundation
/**
 A simple empty body. Used when a POST, PUT, or PATCH request is made that does not require a body of data to be sent.
 */
public struct PRKChopEmptyBody: Encodable {
    public init() { } 
}
