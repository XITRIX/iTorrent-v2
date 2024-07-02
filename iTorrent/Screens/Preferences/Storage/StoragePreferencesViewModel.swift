//
//  StoragePreferencesViewModel.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 03.07.2024.
//

import Combine
import LibTorrent
import MvvmFoundation
import UIKit

class StoragePreferencesViewModel: BasePreferencesViewModel {
    required init() {
        super.init()
        binding()
        reload()
    }

    private let storagesLimit: Int = 4

    private lazy var dataPickerDelegate = DataPickerDelegate(parent: self)
    @Injected private var preferences: PreferencesStorage

    private lazy var documentPicker: UIDocumentPickerViewController = {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        documentPicker.delegate = dataPickerDelegate
        documentPicker.directoryURL = TorrentService.downloadPath
        return documentPicker
    }()
}

private extension StoragePreferencesViewModel {
    func binding() {
        disposeBag.bind {
            preferences.$storageScopes
                .receive(on: .main)
                .sink { [unowned self] _ in
                reload()
            }
        }
    }

    func reload() {
        title.send(%"preferences.storage")

        var sections: [MvvmCollectionSectionModel] = []
        defer { self.sections.send(sections) }

        sections.append(.init(id: "memory") {
            PRSwitchViewModel(with: .init(title: %"preferences.storage.allocate", value: preferences.$allocateMemory.binding))
        })

        sections.append(.init(id: "storages", header: "Storages", footer: "Available: 1/5") {
            PRButtonViewModel(with: .init(title: "iTorrent Default", accessories: [.checkmark()]) { [unowned self] in
                dismissSelection.send()
            })

            preferences.storageScopes.sorted(by: { $0.value.name < $1.value.name }).map { scope in
                PRButtonViewModel(with: .init(title: scope.value.name, accessories: []) { [unowned self] in
                    dismissSelection.send()
                })
            }

            if preferences.storageScopes.count < storagesLimit {
                PRButtonViewModel(with: .init(title: "Add more...", tintedTitle: true) { [unowned self] in
                    dismissSelection.send()
                    navigationService?()?.present(documentPicker, animated: true)
                })
            }
        })
    }
}

private extension StoragePreferencesViewModel {
    class DataPickerDelegate: DelegateObject<StoragePreferencesViewModel>, UIDocumentPickerDelegate {
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  let bookmark = try? url.bookmarkData(),
                  !parent.preferences.storageScopes.values.contains(where: { $0.resolvedURL == url })
            else { return }

            print(url)

            let storage = StorageModel()
            storage.name = url.lastPathComponent
            storage.pathBookmark = bookmark
            storage.resolvedURL = url
            parent.preferences.storageScopes[UUID()] = .init()
        }
    }
}
