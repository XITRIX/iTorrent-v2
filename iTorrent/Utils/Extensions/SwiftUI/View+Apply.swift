//
//  View+Apply.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 13.06.2024.
//

import SwiftUI

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}
