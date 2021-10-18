//
//  URLExtensionTests.swift
//  PorkChopTests
//
//  Created by Timothy Dillman on 10/18/21.
//

import XCTest
@testable import PorkChop
class URLExtensionTests: XCTestCase {

    func test_can_init_from_string() {
        // when
        let result: URL = "http://example.com"
        
        // then
        XCTAssertEqual(result.absoluteString, "http://example.com")
    }
    
    func test_can_init_from_empty_string() {
        // given
        let expectedResult = "invalid_url"
        // when
        let result: URL = ""
        
        // then
        XCTAssertEqual(result.absoluteString, expectedResult)
    }
}
