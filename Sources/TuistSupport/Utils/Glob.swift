//
//  Created by Eric Firestone on 3/22/16.
//  Copyright © 2016 Square, Inc. All rights reserved.
//  Released under the Apache v2 License.
//
//  Adapted from https://gist.github.com/efirestone/ce01ae109e08772647eb061b3bb387c3
import Foundation

// swiftlint:disable:next identifier_name
public let GlobBehaviorBashV3 = Glob.Behavior(
    supportsGlobstar: false,
    includesFilesFromRootOfGlobstar: false,
    includesDirectoriesInResults: true,
    includesFilesInResultsIfTrailingSlash: false
)

// swiftlint:disable:next identifier_name
public let GlobBehaviorBashV4 = Glob.Behavior(
    supportsGlobstar: true, // Matches Bash v4 with "shopt -s globstar" option
    includesFilesFromRootOfGlobstar: true,
    includesDirectoriesInResults: true,
    includesFilesInResultsIfTrailingSlash: false
)
// swiftlint:disable:next identifier_name
public let GlobBehaviorGradle = Glob.Behavior(
    supportsGlobstar: true,
    includesFilesFromRootOfGlobstar: true,
    includesDirectoriesInResults: false,
    includesFilesInResultsIfTrailingSlash: true
)

/**
 Finds files on the file system using pattern matching.
 */
public class Glob: Collection {
    /**
     * Different glob implementations have different behaviors, so the behavior of this
     * implementation is customizable.
     */
    public struct Behavior {
        // If true then a globstar ("**") causes matching to be done recursively in subdirectories.
        // If false then "**" is treated the same as "*"
        let supportsGlobstar: Bool

        // If true the results from the directory where the globstar is declared will be included as well.
        // For example, with the pattern "dir/**/*.ext" the fie "dir/file.ext" would be included if this
        // property is true, and would be omitted if it's false.
        let includesFilesFromRootOfGlobstar: Bool

        // If false then the results will not include directory entries. This does not affect recursion depth.
        let includesDirectoriesInResults: Bool

        // If false and the last characters of the pattern are "**/" then only directories are returned in the results.
        let includesFilesInResultsIfTrailingSlash: Bool

        public init(supportsGlobstar: Bool,
                    includesFilesFromRootOfGlobstar: Bool,
                    includesDirectoriesInResults: Bool,
                    includesFilesInResultsIfTrailingSlash: Bool)
        {
            self.supportsGlobstar = supportsGlobstar
            self.includesFilesFromRootOfGlobstar = includesFilesFromRootOfGlobstar
            self.includesDirectoriesInResults = includesDirectoriesInResults
            self.includesFilesInResultsIfTrailingSlash = includesFilesInResultsIfTrailingSlash
        }
    }

    public static var defaultBehavior = GlobBehaviorBashV4

    public let behavior: Behavior
    var paths = [String]()
    public var startIndex: Int { paths.startIndex }
    public var endIndex: Int { paths.endIndex }

    public init(pattern: String, behavior: Behavior = Glob.defaultBehavior) {
        self.behavior = behavior

        var adjustedPattern = pattern
        let hasTrailingGlobstarSlash = pattern.hasSuffix("**/")
        var includeFiles = !hasTrailingGlobstarSlash

        if behavior.includesFilesInResultsIfTrailingSlash {
            includeFiles = true
            if hasTrailingGlobstarSlash {
                // Grab the files too.
                adjustedPattern += "*"
            }
        }

        let patterns = behavior.supportsGlobstar ? expandGlobstar(pattern: adjustedPattern) : [adjustedPattern]

        for pattern in patterns {
            var gt = glob_t()
            if executeGlob(pattern: pattern, gt: &gt) {
                populateFiles(gt: gt, includeFiles: includeFiles)
            }

            globfree(&gt)
        }

        paths = Array(Set(paths)).sorted { lhs, rhs in
            lhs.compare(rhs) != ComparisonResult.orderedDescending
        }
    }

    // MARK: Private

    private var globalFlags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK

    private func executeGlob(pattern: UnsafePointer<CChar>, gt: UnsafeMutablePointer<glob_t>) -> Bool {
        glob(pattern, globalFlags, nil, gt) == 0
    }

    private func expandGlobstar(pattern: String) -> [String] {
        guard pattern.contains("**") else {
            return [pattern]
        }

        var results = [String]()
        var parts = pattern.components(separatedBy: "**")
        let firstPart = parts.removeFirst()
        var lastPart = parts.joined(separator: "**")

        let fileManager = FileManager.default

        var directories = fileManager.subdirectoriesResolvingSymbolicLinks(atPath: firstPart)
            .map { NSString(string: firstPart).appendingPathComponent($0) }

        if behavior.includesFilesFromRootOfGlobstar {
            // Check the base directory for the glob star as well.
            directories.insert(firstPart, at: 0)

            // Include the globstar root directory ("dir/") in a pattern like "dir/**" or "dir/**/"
            if lastPart.isEmpty {
                results.append(firstPart)
            }
        }

        if lastPart.isEmpty {
            lastPart = "*"
        }
        for directory in directories {
            let partiallyResolvedPattern = NSString(string: directory).appendingPathComponent(lastPart)
            results.append(contentsOf: expandGlobstar(pattern: partiallyResolvedPattern))
        }

        return results
    }

    private func populateFiles(gt: glob_t, includeFiles: Bool) {
        let includeDirectories = behavior.includesDirectoriesInResults
        #if os(Linux)
            let matchesCount = Int(gt.gl_pathc)
        #else
            let matchesCount = Int(gt.gl_matchc)
        #endif
        for i in 0 ..< matchesCount {
            if let path = String(validatingUTF8: gt.gl_pathv[i]!) {
                if !includeFiles || !includeDirectories {
                    let isDirectory = FileManager.default.isDirectory(path: path)
                    if (!includeFiles && !isDirectory) || (!includeDirectories && isDirectory) {
                        continue
                    }
                }

                paths.append(path)
            }
        }
    }

    // MARK: Subscript Support

    public subscript(i: Int) -> String {
        paths[i]
    }

    // MARK: IndexableBase

    public func index(after i: Glob.Index) -> Glob.Index {
        i + 1
    }
}
