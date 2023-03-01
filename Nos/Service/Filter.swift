//
//  Filter.swift
//  Nos
//
//  Created by Christopher Jorgensen on 2/17/23.
//

import Foundation

/// For REQ
final class Filter: Hashable {
    var authorKeys: [String] {
        didSet {
            print("Override author keys to: \(authorKeys)")
        }
    }
    private var kinds: [EventKind]
    private var limit: Int
    
    // For closing redundant requests; not part of hash
    var uuid: String = ""

    init(authorKeys: [String] = [], kinds: [EventKind] = [], pTags: [String] = [], limit: Int = 100) {
        self.authorKeys = authorKeys
        self.kinds = kinds
        self.limit = limit
    }
    
    var dictionary: [String: Any] {
        var filterDict: [String: Any] = ["limit": limit]

        if !authorKeys.isEmpty {
            filterDict["authors"] = authorKeys
        }

        if !kinds.isEmpty {
            filterDict["kinds"] = kinds.map({ $0.rawValue })
        }

        return filterDict
    }

    static func == (lhs: Filter, rhs: Filter) -> Bool {
        lhs.authorKeys == rhs.authorKeys && lhs.kinds == rhs.kinds && lhs.limit == rhs.limit
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(authorKeys)
        hasher.combine(kinds)
        hasher.combine(limit)
    }
}
