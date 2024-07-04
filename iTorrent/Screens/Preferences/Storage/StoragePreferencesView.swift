//
//  StoragePreferencesView.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 03.07.2024.
//

import MvvmFoundation
import SwiftUI
import LibTorrent
import UniformTypeIdentifiers

class StoragePreferencesViewModel: BaseViewModel, ObservableObject {
    @Published var allocateMemory: Bool = false
    @Published var customStoragesVM: [UUID: StorageModel] = [:]
    @Published var currentStorages: UUID?

    required init() {
        super.init()
        allocateMemory = preferences.allocateMemory
        preferences.$storageScopes.assign(to: &$customStoragesVM)

        preferences.$defaultStorage.assign(to: &$currentStorages)

        disposeBag.bind {
            $allocateMemory.sink { [unowned self] in preferences.allocateMemory = $0 }
        }
    }

    @Injected var preferences: PreferencesStorage
}

struct StoragePreferencesView<VM: StoragePreferencesViewModel>: MvvmSwiftUIViewProtocol {
    @ObservedObject var viewModel: VM
    @State var filePickerPresented: Bool = false

    let storagesLimit = 5
    var title: String = %"preferences.storage"

    init(viewModel: VM) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section {
                Toggle("preferences.storage.allocate", isOn: $viewModel.allocateMemory)
            }
            Section {
                Button {
                    viewModel.preferences.defaultStorage = nil
                } label: {
                    HStack {
                        Text(String("iTorrent Default"))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if viewModel.preferences.defaultStorage == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                        }
                    }
                }
                ForEach(Array(viewModel.customStoragesVM.values.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }))) { scope in
                    Button {
                        if scope.allowed {
                            viewModel.preferences.defaultStorage = scope.uuid
                        }
                    } label: {
                        HStack {
                            Text(scope.name)
                                .foregroundStyle(scope.allowed ? Color.primary : Color.secondary)
                            Spacer()
                            if viewModel.preferences.defaultStorage == scope.uuid {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.medium)
                            } else if !scope.allowed {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }.swipeActions {
                        Button(role: .destructive) {
                            viewModel.preferences.storageScopes[scope.uuid] = nil
                            if viewModel.preferences.defaultStorage == scope.uuid {
                                viewModel.preferences.defaultStorage = nil
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                if viewModel.customStoragesVM.count < storagesLimit - 1 {
                    Button("preferences.storage.add") {
                        filePickerPresented = true
                    }
                }
            } header: {
                HStack {
                    Text("preferences.storage.storages")
                    Spacer()
                    Text("preferences.storage.storages.available\(viewModel.customStoragesVM.count + 1)/\(storagesLimit)")
                }
            }
        }.fileImporter(isPresented: $filePickerPresented, allowedContentTypes: [.folder]) { result in
            guard let url = try? result.get() else { return }

            let allowed = url.startAccessingSecurityScopedResource()
            print("Path - \(url) | write permissions - \(allowed)")

            guard let bookmark = try? url.bookmarkData(options: [.minimalBookmark])
            else { return }

            if let storage = viewModel.preferences.storageScopes.values.first(where: {
                      $0.url == url || $0.url == TorrentService.downloadPath
            }) {
                storage.pathBookmark = bookmark
                return
            }

            let storage = StorageModel()
            storage.uuid = UUID()
            storage.name = url.lastPathComponent
            storage.url = url
            storage.allowed = allowed
            storage.resolved = true

            do {
                let name = try url.resourceValues(forKeys: [.localizedNameKey])
                if let name = name.allValues[.localizedNameKey] as? String {
                    storage.name = name
                }
            } catch { }

            storage.pathBookmark = bookmark

            withAnimation {
                viewModel.preferences.storageScopes[storage.uuid] = storage
            }
        }
    }
}
