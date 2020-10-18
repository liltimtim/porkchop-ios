import Foundation
// FIXME: Will probably remove these extensions.  I don't like how they are currently and will further think about how best to
// implement a class / struct that can assist in transforming data into the formats we need.
protocol Transformable {
    func transforming<T: Decodable>(type: T.Type) throws -> T
    func tryTransform<T: Decodable>(type: T.Type) -> T?
}

protocol EncodableData {
    func encode() -> Data?
}

extension Data: Transformable {
    func transforming<T>(type: T.Type) throws -> T where T : Decodable {
        return try JSONDecoder().decode(T.self, from: self)
    }
    
    func tryTransform<T>(type: T.Type) -> T? where T : Decodable {
        return try? JSONDecoder().decode(T.self, from: self)
    }
}

extension Encodable {
    /**
     Shorthand access providing an extension to any object that conforms to Encodable.
     */
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
}

