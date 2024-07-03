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
        reload(storageScopes: preferences.storageScopes)
    }

    private let storagesLimit: Int = 4

    private lazy var dataPickerDelegate = DataPickerDelegate(parent: self)
    @Injected private var preferences: PreferencesStorage

    private lazy var defaultStorageVM = {
        PRButtonViewModel(with: .init(title: "iTorrent Default", accessories: preferences.defaultStorage == nil ? [.checkmark()] : []) { [unowned self] in
            preferences.defaultStorage = nil
            dismissSelection.send()
        })
    }()

    private lazy var customStoragesVM: [UUID: PRButtonViewModel] = [:]

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
                .sink { [unowned self] storageScopes in
                customStoragesVM = [:]
                storageScopes.forEach { scope in
                    let vm = PRButtonViewModel(with: .init(removeAction: { [unowned self] in
                        preferences.storageScopes[scope.key] = nil
                        if preferences.defaultStorage == scope.key {
                            preferences.defaultStorage = nil
                        }
                    }, title: scope.value.name, accessories: preferences.defaultStorage == scope.key ? [.checkmark()] : []) { [unowned self] in
                        preferences.defaultStorage = scope.key
                        dismissSelection.send()
                    })
                    customStoragesVM[scope.key] = vm
                }

                    reload(storageScopes: storageScopes)
            }

            preferences.$defaultStorage.sink { [unowned self] uuid in
                defaultStorageVM.accessories = []
                customStoragesVM.forEach { $0.value.accessories = [] }

                guard let uuid, let customVM = customStoragesVM[uuid] else {
                    return defaultStorageVM.accessories = [.checkmark()]
                }

                customVM.accessories = [.checkmark()]
            }
        }
    }

    func reload(storageScopes: [UUID : StorageModel]) {
        title.send(%"preferences.storage")

        var sections: [MvvmCollectionSectionModel] = []
        defer { self.sections.send(sections) }

        sections.append(.init(id: "memory") {
            PRSwitchViewModel(with: .init(title: %"preferences.storage.allocate", value: preferences.$allocateMemory.binding))
        })

        let footer = preferences.$storageScopes.map { [unowned self] in "Available: \($0.count + 1)/\(storagesLimit + 1)" }.eraseToAnyPublisher()
        sections.append(.init(id: "storages", header: .init("Storages"), footer: footer) {
            defaultStorageVM

            customStoragesVM.values.sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })

            if storageScopes.count < storagesLimit {
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
                  !parent.preferences.storageScopes.values.contains(where: {
                      $0.resolvedURL == url || $0.resolvedURL == TorrentService.downloadPath
                  })
            else { return }

            print(url)

            let storage = StorageModel()
            storage.uuid = UUID()
            storage.name = url.lastPathComponent

            do {
                let name = try url.resourceValues(forKeys: [.localizedNameKey])
                if let name = name.allValues[.localizedNameKey] as? String {
                    storage.name = name
                }
            } catch { }

            storage.pathBookmark = bookmark
            storage.resolvedURL = url
            parent.preferences.storageScopes[storage.uuid] = storage
        }
    }
}
