//
//  URL+Normalization.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 05/07/2024.
//

import Foundation

extension URL {
    var normalized: String {
        if path().hasSuffix("/") {
            return String(path().dropLast())
        }
        return path()
    }
}

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
