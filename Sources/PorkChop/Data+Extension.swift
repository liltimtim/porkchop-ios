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

