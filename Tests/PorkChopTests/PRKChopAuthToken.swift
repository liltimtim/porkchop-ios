import XCTest
@testable import PorkChop
class AuthenticationTokenTests: XCTestCase {
    var sut: PRKChopAuthToken!
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_expirationDateIsNotExpired() {
        // given
        let givenDate = UnitTestUtils.createDate()
        let givenFutureDate = UnitTestUtils.createDate(days: 0, hours: 24, minutes: 0, seconds: 0)
        sut = PRCKChopDefaultAuthenticationToken(expirationDate: UnitTestUtils.createISODate(from: givenFutureDate), token: "", tokenType: "")
        // when
        let result = sut.isExpired(givenDate)
        
        // then
        XCTAssertFalse(result)
    }
    
    func test_expirationDateIsExpired() {
        // given
        let refDate = UnitTestUtils.createDate()
        let today = UnitTestUtils.createDate(days: 0, hours: 24, minutes: 0, seconds: 0)
        sut = PRCKChopDefaultAuthenticationToken(expirationDate: UnitTestUtils.createISODate(from: refDate), token: "", tokenType: "")
        
        // when
        let result = sut.isExpired(today)
        
        // then
        XCTAssertTrue(result)
    }
    
    func test_generatesValidHeaderToken() {
        // given
        let token = "123"
        let tokenType = "bearer"
        let expectedToken: [String:String] = ["Authorization": "\(tokenType) \(token)"]
        sut = PRCKChopDefaultAuthenticationToken(expirationDate: "", token: token, tokenType: tokenType)
        
        // when
        let result = sut.headerToken
        
        // then
        XCTAssertEqual(result, expectedToken)
    }
    
    func test_getDateFromValidDateString() {
        // given
        let expectedDate = UnitTestUtils.createDate()
        let expectedDateString = UnitTestUtils.createISODate(from: expectedDate)
        sut = PRCKChopDefaultAuthenticationToken(expirationDate: expectedDateString, token: "", tokenType: "")
        
        // when
        let result = sut.expDate()
        
        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result, expectedDate)
    }

}

