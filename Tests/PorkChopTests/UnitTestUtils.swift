import Foundation
@testable import PorkChop
struct UnitTestUtils {
    /**
     Creates a reference test date January 1, 2020 00:00:00 via a Gregorian calendar
     */
    static func createDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.day, .year, .month, .hour, .minute, .second], from: Date())
        components.year = 2020
        components.day = 1
        components.month = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }
    
    /**
     Creates a reference test date January 1, 2020 00:00:00 via a Gregorian calendar and returns a date after the given days, hours, minutes, and seconds for that reference date.
     */
    static func createDate(days: Int, hours: Int, minutes: Int, seconds: Int) -> Date {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: DateComponents(day: days, hour: hours, minute: minutes, second: seconds), to: createDate())!
        return date
    }
    
    static func createISODate(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }
    
    static func createISODate(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
