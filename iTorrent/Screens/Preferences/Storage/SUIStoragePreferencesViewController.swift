//
//  SUIStoragePreferencesViewController.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 03.07.2024.
//

import MvvmFoundation
import SwiftUI
import LibTorrent
import UniformTypeIdentifiers

class SUIStoragePreferencesViewModel: BaseViewModel, ObservableObject {
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

struct SUIStoragePreferencesView<VM: SUIStoragePreferencesViewModel>: MvvmSwiftUIViewProtocol {
    @ObservedObject var viewModel: VM
    @State var filePickerPresented: Bool = false

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
                        viewModel.preferences.defaultStorage = scope.uuid
                    } label: {
                        HStack {
                            Text(scope.name)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if viewModel.preferences.defaultStorage == scope.uuid {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.medium)
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
                if viewModel.customStoragesVM.count < 4 {
                    Button(String("Add more...")) {
                        filePickerPresented = true
                    }
                }
            } header: {
                HStack {
                    Text(String("Storages"))
                    Spacer()
                    Text(String("Available: \(viewModel.customStoragesVM.count + 1)/5"))
                }
            }
        }.fileImporter(isPresented: $filePickerPresented, allowedContentTypes: [.folder]) { result in
            guard let url = try? result.get() else { return }

            let allowed = url.startAccessingSecurityScopedResource()
            print("Path - \(url) | write permissions - \(allowed)")

            guard let bookmark = try? url.bookmarkData(options: [.minimalBookmark]),
                  !viewModel.preferences.storageScopes.values.contains(where: {
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

            withAnimation {
                viewModel.preferences.storageScopes[storage.uuid] = storage
            }
        }
    }
}
