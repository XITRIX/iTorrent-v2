//
//  BackgroundService.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 05/04/2024.
//

import Foundation
import Combine
import BackgroundTasks

protocol BackgroundServiceProtocol {
    var isRunning: Bool { get }
    func start() -> Bool
    func stop()
    func prepare() async -> Bool
}

extension BackgroundService {
    enum Mode: Codable {
        case audio
        case location
    }
}

class BackgroundService: BackgroundServiceProtocol {
    @Published var isRunningPublisher: Bool = false

    public static let shared = BackgroundService()

    var isRunning: Bool { impl.isRunning }

    init() {
        if #available(iOS 18, *) {
            let res = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.xitrix.itorrent.background",
                using: nil
            ) { [unowned self] task in
                handleTask(task)
            }
        }
    }

    @discardableResult
    func start() -> Bool {
        if #available(iOS 18, *) {
            let bg = BGContinuedProcessingTaskRequest(identifier: "com.xitrix.itorrent.background")
            bg.title = "Title"
            bg.reason = "Reason"
            do {
                try BGTaskScheduler.shared.submit(bg)
                return true
            } catch {
                print("Unable to submit task: \(error.localizedDescription)")
                return false
            }
        }

        let res = impl.start()
        isRunningPublisher = res
        return res
    }

    func stop() {
        if #available(iOS 18, *) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.xitrix.itorrent.background")
        }

        guard isRunning else { return }
        isRunningPublisher = false
        impl.stop()
    }

    func prepare() async -> Bool {
        await impl.prepare()
    }

    func applyMode(_ mode: Mode) async -> Bool {
        switch mode {
        case .audio:
            impl = AudioBackgroundService()
        case .location:
            impl = LocationBackgroundService()
        }
        return await impl.prepare()
    }

    private var impl: BackgroundServiceProtocol = AudioBackgroundService()
}


@available(iOS 18.0, *)
private extension BackgroundService {
    func handleTask(_ task: BGTask) {
        guard let task = task as? BGContinuedProcessingTask
        else { return }

        task.update(.discreteProgress(totalUnitCount: 50))
    }
}
