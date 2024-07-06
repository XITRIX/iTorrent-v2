//
//  TorrentService.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 29/10/2023.
//

import Combine
import LibTorrent
import MvvmFoundation
import UIKit

extension TorrentService {
    struct TorrentUpdateModel {
        let oldSnapshot: TorrentHandle.Snapshot
        let handle: TorrentHandle
    }
}

class TorrentService {
    @Published var torrents: [TorrentHandle] = []
    var updateNotifier = PassthroughSubject<TorrentUpdateModel, Never>()

    static let shared = TorrentService()
    static var version: String { Version.libtorrentVersion }

    init() { setup() }

    static var downloadPath: URL { try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) }
    static var torrentPath: URL { downloadPath.appending(path: "config") }
    static var fastResumePath: URL { downloadPath.appending(path: "config") }
    static var metadataPath: URL { downloadPath.appending(path: "config") }

    private lazy var session: Session = {
        var settings = Session.Settings()
        print("Working directory: \(Self.downloadPath.path())")
        return .init(Self.downloadPath.path(), torrentsPath: Self.torrentPath.path(), fastResumePath: Self.fastResumePath.path(), settings: .fromPreferences(with: []), storages: PreferencesStorage.shared.storageScopes)
    }()

    private let disposeBag = DisposeBag()

    @Injected private var network: NetworkMonitoringService
    @Injected private var preferences: PreferencesStorage
}

extension TorrentService {
    var storages: Dictionary<UUID, StorageModel> {
        get { session.storages }
        set { session.storages = newValue }
    }

    func checkTorrentExists(with hash: TorrentHashes) -> Bool {
        torrents.contains(where: { $0.snapshot.infoHashes == hash })
    }

    @discardableResult
    func addTorrent(by file: Downloadable, at storage: UUID? = nil) -> Bool {
        guard !torrents.contains(where: { file.infoHashes == $0.snapshot.infoHashes })
        else { return false }

        session.addTorrent(file, to: storage)
        return true
    }

    func removeTorrent(by infoHashes: TorrentHashes, deleteFiles: Bool) {
        guard let handle = torrents.first(where: { $0.snapshot.infoHashes == infoHashes })
        else { return }

        handle.deleteMetadata()
        session.removeTorrent(handle, deleteFiles: deleteFiles)
    }

    func updateSettings(_ settings: Session.Settings) {
        session.settings = settings
    }

    func refreshStorage(_ storage: StorageModel) -> Bool {
        guard storage.resolveSequrityScopes() else { return false }

        let handles = torrents.filter { $0.snapshot.downloadPath.normalized == storage.url.normalized }
        handles.forEach { $0.reload() }
        return true
    }
}

// MARK: - SessionDelegate
extension TorrentService: SessionDelegate {
    func torrentManager(_ manager: Session, didAddTorrent torrent: TorrentHandle) {
        // Do not use snapshot for 'torrent' because it is not generated yet
        guard torrents.firstIndex(where: { $0.snapshot.infoHashes == torrent.infoHashes }) == nil
        else { return }

        torrent.prepareToAdd(into: self)
        torrents.append(torrent)
    }

    func torrentManager(_ manager: Session, didRemoveTorrentWithHash hashesData: TorrentHashes) {
        // Already on Main thread
        guard let index = torrents.firstIndex(where: { $0.snapshot.infoHashes == hashesData })
        else { return }

        let torrent = torrents[index]
        torrent.removePublisher.send(torrent)
        torrents.remove(at: index)
    }

    func torrentManager(_ manager: Session, didReceiveUpdateForTorrent torrent: TorrentHandle) {
        // Do not use snapshot for 'torrent' because it could be not generated yet
        guard let existingTorrent = torrents.first(where: { $0.snapshot.infoHashes == torrent.infoHashes })
        else { return }

        existingTorrent.__unthrottledUpdatePublisher.send()
    }

    func torrentManager(_ manager: Session, didErrorOccur error: Error) {}
}

private extension TorrentService {
    func setup() {
        // Resolve storage scopes, so Core will be able to restore states
        resolveStorageScopes()

        // Pause the core, so it will not deadlock app on making first snapshots
        session.pause();
        torrents = session.torrents.map { torrent in
            torrent.prepareToAdd(into: self)
            return torrent
        }
        // After initialization is done we could resume core
        session.resume();
        session.add(self)

        disposeBag.bind {
            Publishers.combineLatest(
                preferences.settingsUpdatePublisher,
                network.$availableInterfaces
            ) { _, interfaces in
                interfaces
            }
            .sink { [unowned self] interfaces in
                DispatchQueue.main.async { [self] in // Need delay to complete settings apply
                    session.settings = Session.Settings.fromPreferences(with: interfaces)
                }
            }

            preferences.$storageScopes.sink { [unowned self] storages in
                session.storages = storages
            }
        }
    }

    func resolveStorageScopes() {
        preferences.storageScopes.values.forEach { scope in
            scope.resolveSequrityScopes()

            // If storage is not allowed and it used as default, reset default
            if !scope.allowed, preferences.defaultStorage == scope.uuid {
                preferences.defaultStorage = nil
            }
        }
    }
}

private extension TorrentHandle {
    func prepareToAdd(into torrentServide: TorrentService) {
        updateSnapshot()

        disposeBag.bind {
            __unthrottledUpdatePublisher
                .throttle(for: .seconds(0.1), scheduler: .main, latest: true)
                .receive(on: DispatchQueue.global(qos: .userInitiated))
                .sink { [weak self, weak torrentServide] in
                    guard let self, let torrentServide else { return }

                    _ = metadata // trigger to generate
                    let oldSnapshot = snapshot
                    updateSnapshot()
                    let updateModel = TorrentService.TorrentUpdateModel(oldSnapshot: oldSnapshot, handle: self)

                    Task { @MainActor in
                        torrentServide.updateNotifier.send(updateModel)
                        self.__updatePublisher.send(updateModel)
                    }
                }
        }
    }
}
