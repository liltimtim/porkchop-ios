import Foundation
// FIXME: Will probably remove these extensions.  I don't like how they are currently and will further think about how best to
// implement a class / struct that can assist in transforming data into the formats we need.
public protocol Transformable {
    func transforming<T: Decodable>(type: T.Type) throws -> T
    func tryTransform<T: Decodable>(type: T.Type) -> T?
}

public protocol EncodableData {
    func encode() -> Data?
}

extension Data: Transformable {
    var prettyPrintJSON: String? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }
        
        return prettyPrintedString as String
    }
    public func transforming<T>(type: T.Type) throws -> T where T : Decodable {
        return try JSONDecoder().decode(T.self, from: self)
    }
    
    public func tryTransform<T>(type: T.Type) -> T? where T : Decodable {
        return try? JSONDecoder().decode(T.self, from: self)
    }
}

extension Encodable {
    /**
     Shorthand access providing an extension to any object that conforms to Encodable.
     */
    public func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
}

