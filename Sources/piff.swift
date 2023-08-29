// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser

@main
struct piff: ParsableCommand {
    @Argument(help: "the first (left) of the two files to compare")
    var leftFile: String
    
    @Argument(help: "the second (right) of the two files to compare")
    var rightFile: String
    
    @Flag(help: "use normal output format")
    var normal = false
    
    mutating func run() throws {
        let leftLines: [String]
        let rightLines: [String]
        
        do {
            leftLines = try lines(leftFile)
        } catch {
            printerr(error)
            return
        }
        
        do {
            rightLines = try lines(rightFile)
        } catch {
            printerr(error)
            return
        }
        
        let diff = diff(leftLines, rightLines)
        
        if normal {
            let normalDiff = NormalDiff(diff)
            
            print(" \(normalDiff)")
        } else {
            print("\(diff)")
        }
    }
}
