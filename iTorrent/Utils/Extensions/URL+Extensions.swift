//
//  URL+Normalization.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 05/07/2024.
//

import Foundation

extension URL {
    var normalized: Self {
        if path().hasSuffix("/") {
            return URL(fileURLWithPath: String(path().dropLast()))
        }
        return self
    }
}

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
