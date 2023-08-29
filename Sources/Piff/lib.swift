//
//  lib.swift
//  
//
//  Created by Philipp Brendel on 28.08.23.
//

import Foundation

func lines(_ filePath: String) throws -> [String] {
    try String(contentsOfFile: filePath)
        .components(separatedBy: .newlines)
}

func printerr(_ message: String) {
    fputs("\(message)\n", stderr)
}

func printerr(_ error: Error) {
    printerr(error.localizedDescription)
}

struct LcsLength {
    let m: Int
    let n: Int
    var matrix: [Int]
    
    init(m: Int, n: Int) {
        self.m = m
        self.n = n
        self.matrix = Array(repeating: 0, count: n * m)
    }
    
    subscript(_ i: Int, _ j: Int) -> Int {
        get { return matrix[i + j * m] }
        set { matrix[i + j * m] = newValue }
    }
}

func lcsLength(x: [String], y: [String]) -> LcsLength {
    let m = x.count
    let n = y.count
    var c = LcsLength(m: m + 1, n: n + 1)
    
    for i in 1...m {
        for j in 1...n {
            if x[i - 1] == y[j - 1] {
                c[i, j] = c[i - 1, j - 1] + 1
            } else {
                c[i, j] = max(c[i, j - 1], c[i - 1, j])
            }
        }
    }
    
    return c
}

func backtrack(_ c: LcsLength, _ x: [String], _ y: [String], _ i: Int, _ j: Int) -> String {
    if i == 0 || j == 0 {
        return ""
    }
    if x[i - 1] == y[j - 1] {
        return backtrack(c, x, y, i - 1, j - 1) + x[i - 1]
    }
    if c[i, j - 1] > c[i - 1, j] {
        return backtrack(c, x, y, i, j - 1)
    }
    return backtrack(c, x, y, i - 1, j)
}

func lcs(x: [String], y: [String]) -> String {
    let c = lcsLength(x: x, y: y)
    
    return backtrack(c, x, y, x.count, y.count)
}

func printDiff(_ c: LcsLength, _ x: [String], _ y: [String], _ i: Int, _ j: Int) {
    if i > 0 && j > 0 && x[i - 1] == y[j - 1] {
        printDiff(c, x, y, i - 1, j - 1)
        print("  \(x[i - 1])")
    } else if j > 0 && (i == 0 || c[i, j - 1] >= c[i - 1, j]) {
        printDiff(c, x, y, i, j - 1)
        print("+ \(y[j - 1])")
    } else if i > 0 && (j == 0 || c[i, j - 1] < c[i - 1, j]) {
        printDiff(c, x, y, i - 1, j)
        print("- \(x[i - 1])")
    } else {
        print("")
    }
}

func printDiff(_ x: [String], _ y: [String]) {
    let c = lcsLength(x: x, y: y)
    
    printDiff(c, x, y, x.count, y.count)
}

public struct UnifiedDiff: CustomDebugStringConvertible {
    public enum Change: CustomDebugStringConvertible {
        case none(String)
        case add(String)
        case rem(String)
        
        public var debugDescription: String {
            switch self {
            case .none(let text):
                return " \(text)"
            case .add(let text):
                return "+\(text)"
            case .rem(let text):
                return "-\(text)"
            }
        }
    }

    public let changes: [Change]
    
    public var debugDescription: String {
        changes.map {String(describing: $0)}.joined(separator: "\n")
    }
}

public extension UnifiedDiff.Change {
    var caseName: String {
        switch self {
        case .none: return "none"
        case .add: return "add"
        case .rem: return "rem"
        }
    }
    
    var associatedValue: String {
        switch self {
        case .none(let value), .add(let value), .rem(let value):
            return value
        }
    }
    
    func toGroupedChange() -> GroupedUnifiedDiff.Change {
            switch self {
            case .none(let value):
                return .none([value])
            case .add(let value):
                return .add([value])
            case .rem(let value):
                return .rem([value])
            }
        }
}

extension GroupedUnifiedDiff.Change {
    var caseName: String {
        switch self {
        case .none: return "none"
        case .add: return "add"
        case .rem: return "rem"
        }
    }
    
    mutating func appendValue(_ value: String) {
        switch self {
        case .none(var values):
            values.append(value)
            self = .none(values)
        case .add(var values):
            values.append(value)
            self = .add(values)
        case .rem(var values):
            values.append(value)
            self = .rem(values)
        }
    }
}


public struct GroupedUnifiedDiff {
    public enum Change {
        case none([String])
        case add([String])
        case rem([String])
    }
    
    public let changes: [Change]
    
    public init(_ diff: UnifiedDiff) {
        changes = Self.groupChanges(diff.changes)
    }
    
    static func groupChanges(_ ungroupedChanges: [UnifiedDiff.Change]) -> [Change] {
        let groupedChanges =
            ungroupedChanges.reduce(into: [GroupedUnifiedDiff.Change](), { result, change in
                if result.last?.caseName == change.caseName {
                    result[result.count - 1].appendValue(change.associatedValue)
                } else {
                    result.append(change.toGroupedChange())
                }
            })
        
        return groupedChanges
    }
}

public struct NormalDiff: CustomDebugStringConvertible {
    public enum Change: CustomDebugStringConvertible {
        case add(Int, Range<Int>, [String])
        case rem(Range<Int>, Int, [String])
        //case change(Range<Int>, Range<Int>)
        
        public var debugDescription: String {
            switch self {
            case let .add(i, r, lines):
                return "\(i)a\(r.lowerBound),\(r.upperBound)\n\(lines.map {"> \($0)"}.joined(separator: "\n"))"
            case let .rem(r, j, lines):
                return "\(r.lowerBound),\(r.upperBound)d\(j)\n\(lines.map {"< \($0)"}.joined(separator: "\n"))"
            }
        }
    }
    
    public let changes: [Change]
    
    public init(_ diff: GroupedUnifiedDiff) {
        self.changes = Self.computeChanges(diff)
    }
    
    public init(_ diff: UnifiedDiff) {
        self.init(GroupedUnifiedDiff(diff))
    }
    
    public init(_ x: [String], _ y: [String]) {
        self.init(diff(x, y))
    }
    
    public init(_ x: URL, _ y: URL) throws {
        try self.init(lines(x.path), lines(y.path))
    }
    
    static func computeChanges(_ patchy: GroupedUnifiedDiff) -> [Change] {
        var changes: [Change] = []
        var i = 0
        var j = 0

        for change in patchy.changes {
            switch change {
            case .add(let lines):
                changes.append(.add(i, (j+1)..<(j + lines.count), lines))
                j += lines.count
            case .rem(let lines):
                changes.append(.rem((i+1)..<(i + lines.count), j, lines))
                i += lines.count
            case .none(let lines):
                i += lines.count
                j += lines.count
            }
        }

        return changes
    }
    
    public var debugDescription: String {
        changes.map {"\($0)"}.joined(separator: "\n")
    }
}

func diff(_ c: LcsLength, _ x: [String], _ y: [String], _ i: Int, _ j: Int, _ changes: inout [UnifiedDiff.Change]) {
    if i > 0 && j > 0 && x[i - 1] == y[j - 1] {
        diff(c, x, y, i - 1, j - 1, &changes)
        changes.append(.none(x[i - 1]))
    } else if j > 0 && (i == 0 || c[i, j - 1] >= c[i - 1, j]) {
        diff(c, x, y, i, j - 1, &changes)
        changes.append(.add(y[j - 1]))
    } else if i > 0 && (j == 0 || c[i, j - 1] < c[i - 1, j]) {
        diff(c, x, y, i - 1, j, &changes)
        changes.append(.rem(x[i - 1]))
    }
}

public func diff(_ left: [String], _ right: [String]) -> UnifiedDiff {
    let c = lcsLength(x: left, y: right)
    var changes: [UnifiedDiff.Change] = []
    
    diff(c, left, right, left.count, right.count, &changes)
    
    return UnifiedDiff(changes: changes)
}
