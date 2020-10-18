import XCTest

@testable import PorkChop

class DataExtensionTests: XCTestCase {
    
    func test_canDecodeData() {
        // given
        let givenJSON = SampleJSONObject()
        let data = try! JSONEncoder().encode(givenJSON)
        
        // when
        let result = try? data.transforming(type: SampleJSONObject.self)
        
        // then
        XCTAssertEqual(result, givenJSON)
    }
    
    func test_tryDecodeInvalidData() {
        // given
        let givenData =
        """
         { }
        """.data(using: .utf8)
        XCTAssertNotNil(givenData)
        
        // when
        let result = givenData?.tryTransform(type: SampleJSONObject.self)
        
        // then
        XCTAssertNil(result)
    }
    
    func test_canDecodeFromRawData() {
        // given
        let givenData =
        """
        { "id": "123" }
        """
            .data(using: .utf8)
        XCTAssertNotNil(givenData)
        
        // when
        let result = givenData?.tryTransform(type: SampleJSONObject.self)
        
        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, "123")
    }
    
    func test_canDecodeFromRawDataDoesNotThrow() {
        // given
        let givenData =
        """
        { "id": "123" }
        """
            .data(using: .utf8)
        XCTAssertNotNil(givenData)
        
        // when
        do {
            let result = try givenData?.transforming(type: SampleJSONObject.self)
            // then
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.id, "123")
        } catch let err {
            XCTFail("Was not expecting an error but got one from canDecodeFromRawDataDoesNotThrow: \(err.localizedDescription)")
        }
        
    }
    
    func test_canEncodeToData() {
        // when
        let result = SampleJSONObject().encode()
        
        // then
        XCTAssertNotNil(result)
        guard let r = result else {
            XCTFail("Result is nil canEcnodeToData")
            return
        }
        XCTAssertGreaterThan(r.count, 0)
    }
}

fileprivate struct SampleJSONObject: Encodable, Decodable, Equatable {
    /* must be var type otherwise we cannot decode/encode it properly */
    var id: String = UUID().uuidString
    
    static func == (lhs: SampleJSONObject, rhs: SampleJSONObject) -> Bool {
        return lhs.id == rhs.id
    }
}
