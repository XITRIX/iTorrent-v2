//
//  TorrentDetailsViewModel.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 30/10/2023.
//

import Combine
import LibTorrent
import MvvmFoundation
import UIKit

class TorrentDetailsViewModel: BaseViewModelWith<TorrentHandle> {
    private var torrentHandle: TorrentHandle!

    @Published var sections: [MvvmCollectionSectionModel] = []
    @Published var title: String = ""
    @Published var isPaused: Bool = false

    let dismissSignal = PassthroughSubject<Void, Never>()

    override func prepare(with model: TorrentHandle) {
        torrentHandle = model
        title = model.name

        dataUpdate()
        reload()

        disposeBag.bind {
            torrentHandle.updatePublisher
                .sink { [unowned self] _ in
                    dataUpdate()
                }

            torrentHandle.updatePublisher
                .map { $0.handle.snapshot.friendlyState }
                .removeDuplicates()
                .sink { [unowned self] _ in
                    reload()
                }

            torrentHandle.removePublisher.sink { [unowned self] _ in
                dismissSignal.send()
            }

            sequentialModel.$isOn.sink { [unowned self] value in
                torrentHandle.setSequentialDownload(value)
            }
        }

        hashModel.longPressAction = { [unowned self] in
            UIPasteboard.general.string = hashModel.detail
            alertWithTimer(message: %"details.copy.hash.title")
        }

        hashModelV2.longPressAction = { [unowned self] in
            UIPasteboard.general.string = hashModelV2.detail
            alertWithTimer(message: %"details.copy.hashV2.title")
        }

        creatorModel.longPressAction = { [unowned self] in
            UIPasteboard.general.string = creatorModel.detail
            alertWithTimer(message: %"details.copy.creator.title")
        }

        commentModel.longPressAction = { [unowned self] in
            UIPasteboard.general.string = commentModel.detail
            alertWithTimer(message: %"details.copy.comment.title")
        }
    }

    private lazy var dataPickerDelegate = DataPickerDelegate(parent: self)

    private let stateModel = DetailCellViewModel(title: %"details.state")

    private let downloadModel = DetailCellViewModel(title: %"details.speed.download")
    private let uploadModel = DetailCellViewModel(title: %"details.speed.upload")
    private let timeLeftModel = DetailCellViewModel(title: %"details.speed.timeRemains")

    private let sequentialModel = ToggleCellViewModel(title: %"details.downloading.sequential")
    private let progressModel = TorrentDetailProgressCellViewModel(title: %"details.downloading.progress")

    private let hashModel = DetailCellViewModel(title: %"details.info.hash", spacer: 80)
    private let hashModelV2 = DetailCellViewModel(title: %"details.info.hashV2", spacer: 80)
    private let creatorModel = DetailCellViewModel(title: %"details.info.creator", spacer: 80)
    private let commentModel = DetailCellViewModel(title: %"details.info.comment", spacer: 80)
    private let createdModel = DetailCellViewModel(title: %"details.info.created")
    private let addedModel = DetailCellViewModel(title: %"details.info.added")

    private let selectedModel = DetailCellViewModel(title: %"details.transfer.selectedTotal")
    private let completedModel = DetailCellViewModel(title: %"details.transfer.completed")
    private let selectedProgressModel = DetailCellViewModel(title: %"details.transfer.progressSelectedTotal")
    private let downloadedModel = DetailCellViewModel(title: %"details.transfer.downloaded")
    private let uploadedModel = DetailCellViewModel(title: %"details.transfer.uploaded")
    private let seedersModel = DetailCellViewModel(title: %"details.transfer.seeders")
    private let leechersModel = DetailCellViewModel(title: %"details.transfer.leechers")

    private lazy var downloadPathModel = PRButtonViewModel(with: .init(title: %"details.path.browse", value: Just("Default").eraseToAnyPublisher(), accessories: [
        .popUpMenu(
            .init(title: %"preferences.appearance.theme.action", children: [
                UIAction(title: "Default", state: .off) { _ in },
                UIAction(title: "Browse", state: .off) { [unowned self] _ in
                    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
                    documentPicker.delegate = dataPickerDelegate
                    documentPicker.directoryURL = TorrentService.downloadPath
                    navigationService?()?.present(documentPicker, animated: true)
                },
            ]), options: .init(tintColor: .tintColor)
        ),
    ]))

    private lazy var trackersModel = DetailCellViewModel(title: %"details.actions.trackers") { [unowned self] in
        navigate(to: TorrentTrackersViewModel.self, with: torrentHandle, by: .show)
    }
    private lazy var filesModel = DetailCellViewModel(title: %"details.actions.files") { [unowned self] in
        navigate(to: TorrentFilesViewModel.self, with: .init(torrentHandle: torrentHandle), by: .show)
    }
}

extension TorrentDetailsViewModel {
    var shareAvailable: AnyPublisher<Bool, Never> {
        torrentHandle.updatePublisher
            .map { !$0.handle.snapshot.torrentFilePath.isNilOrEmpty }
            .eraseToAnyPublisher()
    }

    func resume() {
        torrentHandle.resume()
    }

    func pause() {
        torrentHandle.pause()
    }

    func rehash() {
        alert(title: %"details.rehash.title", message: %"details.rehash.message", actions: [
            .init(title: %"common.cancel", style: .cancel),
            .init(title: %"details.rehash.action", style: .destructive, action: { [unowned self] in
                torrentHandle.rehash()
            })
        ])
    }

    func removeTorrent() {
        alert(title: %"torrent.remove.title", message: torrentHandle.snapshot.name, actions: [
            .init(title: %"torrent.remove.action.dropData", style: .destructive, action: { [unowned self] in
                TorrentService.shared.removeTorrent(by: torrentHandle.snapshot.infoHashes, deleteFiles: true)
            }),
            .init(title: %"torrent.remove.action.keepData", style: .default, action: { [unowned self] in
                TorrentService.shared.removeTorrent(by: torrentHandle.snapshot.infoHashes, deleteFiles: false)
            }),
            .init(title: %"common.cancel", style: .cancel)
        ])
    }

    func shareMagnet() {
        UIPasteboard.general.string = torrentHandle.snapshot.magnetLink
        alertWithTimer(message: %"details.share.magnetCopy.result")
    }

    var torrentFilePath: String? {
        torrentHandle.snapshot.torrentFilePath
    }

    var infoHashes: TorrentHashes {
        torrentHandle.snapshot.infoHashes
    }
}

private extension TorrentDetailsViewModel {
    func dataUpdate() {
        isPaused = torrentHandle.snapshot.isPaused
        stateModel.detail = "\(torrentHandle.snapshot.friendlyState.name)" // "\(torrentHandle.snapshot.state.rawValue) | \(torrentHandle.snapshot.isPaused ? "Paused" : "Running")"

        downloadModel.detail = "\(torrentHandle.snapshot.downloadRate.bitrateToHumanReadable)/s"
        uploadModel.detail = "\(torrentHandle.snapshot.uploadRate.bitrateToHumanReadable)/s"
        timeLeftModel.detail = torrentHandle.snapshot.timeRemains

        sequentialModel.isOn = torrentHandle.snapshot.isSequential
        progressModel.progress = torrentHandle.snapshot.progress
        progressModel.segmentedProgress = torrentHandle.snapshot.segmentedProgress

        if torrentHandle.snapshot.infoHashes.hasV1 {
            hashModel.detail = torrentHandle.snapshot.infoHashes.v1.hex
        }
        if torrentHandle.snapshot.infoHashes.hasV2 {
            hashModelV2.detail = torrentHandle.snapshot.infoHashes.v2.hex
        }
        creatorModel.detail = torrentHandle.snapshot.creator ?? ""
        commentModel.detail = torrentHandle.snapshot.comment ?? ""

        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/YYYY"
            return formatter
        }()

        if let created = torrentHandle.snapshot.creationDate {
            createdModel.detail = formatter.string(from: created)
        }
        addedModel.detail = formatter.string(from: torrentHandle.metadata.dateAdded)

        selectedModel.detail = "\(torrentHandle.snapshot.totalWanted.bitrateToHumanReadable) / \(torrentHandle.snapshot.total.bitrateToHumanReadable)"
        completedModel.detail = "\(torrentHandle.snapshot.totalDone.bitrateToHumanReadable)"
        selectedProgressModel.detail = "\(String(format: "%.2f", torrentHandle.snapshot.progress * 100))% / \(String(format: "%.2f", torrentHandle.snapshot.progressWanted * 100))%"
        downloadedModel.detail = "\(torrentHandle.snapshot.totalDownload.bitrateToHumanReadable)"
        uploadedModel.detail = "\(torrentHandle.snapshot.totalUpload.bitrateToHumanReadable)"
        seedersModel.detail = "\(torrentHandle.snapshot.numberOfSeeds)(\(torrentHandle.snapshot.numberOfTotalSeeds))"
        leechersModel.detail = "\(torrentHandle.snapshot.numberOfLeechers)(\(torrentHandle.snapshot.numberOfTotalLeechers))"
    }

    func reload() {
        var sections: [MvvmCollectionSectionModel] = []
        defer { self.sections = sections }

        sections.append(.init(id: "state") {
            stateModel
        })

        if !torrentHandle.snapshot.isPaused,
           torrentHandle.snapshot.friendlyState != .checkingFiles
        {
            sections.append(.init(id: "speed", header: %"details.speed") {
                let isSeeding = torrentHandle.snapshot.friendlyState == .seeding
                if !isSeeding {
                    downloadModel
                }
                uploadModel
                if !isSeeding {
                    timeLeftModel
                }
            })
        }

        sections.append(.init(id: "download", header: %"details.downloading") {
            sequentialModel
            progressModel
        })
//
        sections.append(.init(id: "info", header: %"details.info") {
            if torrentHandle.snapshot.infoHashes.hasV1 {
                hashModel
            }
            if torrentHandle.snapshot.infoHashes.hasV2 {
                hashModelV2
            }

            if !creatorModel.detail.isEmpty {
                creatorModel
            }

            if !commentModel.detail.isEmpty {
                commentModel
            }

            if !creatorModel.detail.isEmpty {
                createdModel
            }
            addedModel
        })

        sections.append(.init(id: "transfer", header: %"details.transfer") {
            selectedModel
            completedModel
            selectedProgressModel
            downloadedModel
            uploadedModel
            seedersModel
            leechersModel
        })

        sections.append(.init(id: "path", header: %"details.path") {
            downloadPathModel
        })

        sections.append(.init(id: "actions", header: %"details.actions") {
            trackersModel
            filesModel
        })
    }
}

private extension TorrentDetailsViewModel {
    class DataPickerDelegate: DelegateObject<TorrentDetailsViewModel>, UIDocumentPickerDelegate {

    }
}

extension TorrentHandle.Snapshot {
    var timeRemains: String {
        guard downloadRate > 0 else { return %"time.infinity" }
        guard totalWanted >= totalWantedDone else { return "Almost done" }
        return ((totalWanted - totalWantedDone) / downloadRate).timeString
    }

    var segmentedProgress: [Double] {
        pieces?.map { $0.doubleValue } ?? [0]
    }
}
