//
//  File.swift
//
//
//  Created by Timothy Dillman on 10/18/21.
//

import Foundation

extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        if value.isEmpty {
            self = URL(string: "invalid_url")!
        } else {
            self = URL(string: value)!
        }
    }
}
