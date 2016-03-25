//
//  TextTable.swift
//  SwiftyTextTable
//
//  Created by Scott Hoyt on 2/3/16.
//  Copyright © 2016 Scott Hoyt. All rights reserved.
//

import Foundation

// MARK: Console Escape Stripping
private let strippingPattern = "(?:\u{001B}\\[(?:[0-9]|;)+m)*(.*?)(?:\u{001B}\\[0m)+"

// We can safely force try this regex because the pattern has be tested to work.
// swiftlint:disable:next force_try
private let strippingRegex = try! NSRegularExpression(pattern: strippingPattern, options: [])

// MARK: - TextTable Protocols

public protocol TextTableObject {
    static var tableHeaders: [String] { get }
    var tableValues: [CustomStringConvertible] { get }
}

extension String: CustomStringConvertible {
    public var description: String {
        return self
    }
}

private extension String {
    private func withPadding(count: Int) -> String {
        let length = characters.count
        if length < count {
            return self +
                repeatElement(" ", count: count - length).joined(separator: "")
        }
        return self
    }

    func stripped() -> String {
        let matches = strippingRegex
            .matches(in: self, options: [], range: NSRange(location: 0, length: self.characters.count))
            .map {
                NSString(string: self).substring(with: $0.range(at: 1))
        }
        return matches.isEmpty ? self : matches.joined(separator: "")
    }

    func strippedLength() -> Int {
        return stripped().characters.count
    }
}

private func fence(strings: [String], separator: String) -> String {
    return separator + strings.joined(separator: separator) + separator
}

public struct TextTableColumn {
    public var header: String
    private var values: [String] = []

    public init(header: String) {
        self.header = header
    }

    public var width: Int {
        return max(header.strippedLength(), values.reduce(0) { max($0, $1.strippedLength()) })
    }
}

public struct TextTable {
    private var columns: [TextTableColumn]
    public var columnFence = "|"
    public var rowFence = "-"
    public var cornerFence = "+"

    public init(columns: [TextTableColumn]) {
        self.columns = columns
    }

    public init<T: TextTableObject>(objects: [T]) {
        columns = objects.isEmpty ? [] : objects[0].dynamicType.tableHeaders.map { TextTableColumn(header: $0) }
        objects.forEach { addRow($0.tableValues) }
    }

    public mutating func addRow(values: [CustomStringConvertible]) {
        let values = values.count >= columns.count ? values :
            values + [CustomStringConvertible](repeating: "", count: columns.count - values.count)
        columns = zip(columns, values).map {
            (column, value) in
            var column = column
            column.values.append(value.description)
            return column
        }
    }

    public func render() -> String {
        let separator = fence(columns.map({ column in
            return repeatElement(rowFence, count: column.width + 2).joined(separator: "")
        }), separator: cornerFence)
        let header = fence(columns.map({ " \($0.header.withPadding($0.width)) " }), separator: columnFence)
        let values = columns.isEmpty ? "" : (0..<columns.first!.values.count).map({ rowIndex in
            fence(columns.map({ " \($0.values[rowIndex].withPadding($0.width)) " }), separator: columnFence)
        }).joined(separator: "\n")
        return [separator, header, separator, values, separator].joined(separator: "\n")
    }
}

#if !swift(>=3)
    internal func repeatElement<T>(element: T, count: Int) -> Repeat<T> {
        return Repeat(count: count, repeatedValue: element)
    }

    extension SequenceType where Generator.Element == String {
        internal func joined(separator separator: String) -> String {
            return joinWithSeparator(separator)
        }
    }

    extension Array {
        internal init(repeating repeatedValue: Element, count: Int) {
            self.init(count: count, repeatedValue: repeatedValue)
        }
    }
#endif

#if !swift(>=3) || os(Linux)
    extension NSString {
        internal func substring(with range: NSRange) -> String {
            return substringWithRange(range)
        }
    }

    extension NSRegularExpression {
        internal func matches(in string: String, options: NSMatchingOptions = [], range: NSRange) -> [NSTextCheckingResult] {
            return matchesInString(string, options: options, range: range)
        }
    }

    extension NSTextCheckingResult {
        internal func range(at idx: Int) -> NSRange {
            return rangeAtIndex(idx)
        }
    }
#endif
