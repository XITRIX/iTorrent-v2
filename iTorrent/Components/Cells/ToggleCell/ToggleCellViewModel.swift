//
//  ToggleCellViewModel.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 02/11/2023.
//

import Combine
import MvvmFoundation

// extension DetailCellViewModel {
//    struct Config {
//        var title: String = ""
//        var detail: String = ""
//    }
// }

class ToggleCellViewModel: BaseViewModel, ObservableObject {
    var selectAction: (() -> Void)?

    @Published var title: String = ""
    @Published var isOn: Bool = false
    @Published var isEnabled: Bool = true
    @Published var spacer: Double = 0
    @Published var isBold: Bool = true

    init(title: String = "", isOn: Bool = false, isEnabled: Bool = true, spacer: Double = 24, isBold: Bool = true) {
        self.title = title
        self.isOn = isOn
        self.isEnabled = isEnabled
        self.spacer = spacer
        self.isBold = isBold
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    override func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }

//    override func isEqual(to other: MvvmViewModel) -> Bool {
//        guard let other = other as? Self else { return false }
//        return title == other.title
//    }
}
