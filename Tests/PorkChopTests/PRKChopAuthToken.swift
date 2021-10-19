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
    
    func test_createTokenWithSecondsExpiration() {
        // given
        let givenDate = UnitTestUtils.createDate()
        let givenFutureDate = givenDate.addingTimeInterval(45)
        sut = PRCKChopDefaultAuthenticationToken(refDate: givenDate, expDateInSeconds: 45, token: "", tokenType: "", refreshToken: nil)
        // when
        let result = sut.expDate()
        // then
        XCTAssertEqual(givenFutureDate, result)
    }
    
    func test_expirationDateIsNotExpired() {
        // given
        let givenDate = UnitTestUtils.createDate()
        let givenFutureDate = UnitTestUtils.createDate(days: 0, hours: 24, minutes: 0, seconds: 0)
        sut = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenFutureDate), token: "", tokenType: "")
        // when
        let result = sut.isExpired(givenDate)
        
        // then
        XCTAssertFalse(result)
    }
    
    func test_expirationDateIsExpired() {
        // given
        let refDate = UnitTestUtils.createDate()
        let today = UnitTestUtils.createDate(days: 0, hours: 24, minutes: 0, seconds: 0)
        sut = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: refDate), token: "", tokenType: "")
        
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
        sut = PRCKChopDefaultAuthenticationToken(expDate: "", token: token, tokenType: tokenType)
        
        // when
        let result = sut.headerToken
        
        // then
        XCTAssertEqual(result, expectedToken)
    }
    
    func test_getDateFromValidDateString() {
        // given
        let expectedDate = UnitTestUtils.createDate()
        let expectedDateString = UnitTestUtils.createISODate(from: expectedDate)
        sut = PRCKChopDefaultAuthenticationToken(expDate: expectedDateString, token: "", tokenType: "")
        
        // when
        let result = sut.expDate()
        
        // then
        XCTAssertNotNil(result)
        XCTAssertEqual(result, expectedDate)
    }
    
    func test_generatesValidAPIQueryParams() {
        // given
        let token = PRKChopDefaultQueryAPIToken("apiToken", "123")
        let expectedQueryItem = URLQueryItem(name: "apiToken", value: "123")
        
        // then
        XCTAssertEqual(token.queryItem, expectedQueryItem)
    }
    
    func test_tokenIsAboutToExpire_outsideOfExpirationRange_Hours() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 0, hours: 24, minutes: 0, seconds: 0) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 0, hours: 12, minutes: 0, seconds: 0)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .hours, tolerance: 4)
        // then
        XCTAssertFalse(result)
    }
    
    func test_tokenIsAboutToExpire_insideOfExpirationRange_Hours() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 0, hours: 24, minutes: 0, seconds: 0) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 0, hours: 22, minutes: 0, seconds: 0)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .hours, tolerance: 4)
        // then
        XCTAssertTrue(result)
    }
    
    func test_tokenIsAboutToExpire_outsideOfExpirationRange_Days() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 30, hours: 0, minutes: 0, seconds: 0) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 25, hours: 0, minutes: 0, seconds: 0)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .days, tolerance: 1)
        // then
        XCTAssertFalse(result)
    }
    
    func test_tokenIsAboutToExpire_insideOfExpirationRange_Days() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 30, hours: 0, minutes: 0, seconds: 0) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 29, hours: 0, minutes: 0, seconds: 0)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .days, tolerance: 2)
        // then
        XCTAssertTrue(result)
    }
    
    func test_tokenIsAboutToExpire_outsideOfExpirationRange_Minutes() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 30, seconds: 0) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 0, seconds: 0)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .minutes, tolerance: 5)
        // then
        XCTAssertFalse(result)
    }
    
    func test_tokenIsAboutToExpire_insideOfExpirationRange_Minutes() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 30, seconds: 0) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 26, seconds: 0)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .minutes, tolerance: 5)
        // then
        XCTAssertTrue(result)
    }
    
    func test_tokenIsAboutToExpire_outsideOfExpirationRange_Seconds() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 0, seconds: 30) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 0, seconds: 10)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .seconds, tolerance: 5)
        // then
        XCTAssertFalse(result)
    }
    
    func test_tokenIsAboutToExpire_insideOfExpirationRange_Seconds() {
        // given
        let givenExpDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 0, seconds: 30) // create day 1 day in future from Jan1
        let token = PRCKChopDefaultAuthenticationToken(expDate: UnitTestUtils.createISODate(from: givenExpDate), token: "", tokenType: "")
        let givenDate = UnitTestUtils.createDate(days: 0, hours: 0, minutes: 0, seconds: 26)
        // when
        let result = token.isAboutToExpire(givenDate, toleranceLevel: .seconds, tolerance: 5)
        // then
        XCTAssertTrue(result)
    }
}

