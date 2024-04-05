//
//  SceneDelegate.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 29/10/2023.
//

import LibTorrent
import MvvmFoundation
import UIKit

class SceneDelegate: MvvmSceneDelegate {
    override func initialSetup() {
        UIView.enableUIColorsToLayer()
    }

    override func register(in container: Container) {
        container.register(type: UINavigationController.self, factory: BaseNavigationController.init)
        container.register(type: UISplitViewController.self, factory: BaseSplitViewController.init)
        container.registerSingleton(factory: { TorrentService.shared })
        container.registerSingleton(factory: NetworkMonitoringService.init)
        container.registerSingleton(factory: { PreferencesStorage.shared })
        container.registerSingleton(factory: { BackgroundService.shared })
        container.registerDaemon(factory: TorrentMonitoringService.init)
    }

    override func routing(in router: Router) {
        // MARK: Controllers
        router.register(TorrentListViewController<TorrentListViewModel>.self)
        router.register(TorrentDetailsViewController<TorrentDetailsViewModel>.self)
        router.register(TorrentFilesViewController<TorrentFilesViewModel>.self)
        router.register(TorrentAddViewController<TorrentAddViewModel>.self)
        router.register(TorrentTrackersViewController<TorrentTrackersViewModel>.self)

        router.register(BasePreferencesViewController<PreferencesViewModel>.self)
        router.register(BasePreferencesViewController<ProxyPreferencesViewModel>.self)
        router.register(BasePreferencesViewController<ConnectionPreferencesViewModel>.self)
        router.register(PreferencesSectionGroupingViewController.self)

        // MARK: Cells
        router.register(TorrentListItemView.self)
        router.register(TorrentDetailProgressCellView.self)

        router.register(TrackerCellView.self)

        router.register(DetailCellView.self)
        router.register(ToggleCellView.self)

        router.register(PRSwitchView.self)
        router.register(PRButtonView.self)
        router.register(PRStorageCell.self)
        router.register(PRColorPickerCell.self)
    }

    override func resolveRootVC(with router: Router) -> UIViewController {
        let vc = router.resolve(TorrentListViewModel())

        let nvc = UINavigationController.resolve()
        nvc.viewControllers = [vc]

        let svc = UISplitViewController.resolve()
        svc.viewControllers = [nvc]

        return svc
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { context in
            let url = context.url

            // Open by hash from Life Activity
            if url.absoluteString.hasPrefix("iTorrent:hash:") {
                let hash = url.absoluteString.replacingOccurrences(of: "iTorrent:hash:", with: "")
                guard let torrent = TorrentService.shared.torrents.first(where: { $0.infoHashes.best.hex == hash })
                else { return }

                AppDelegate.showTorrentDetailScreen(with: torrent)
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }
            guard url.startAccessingSecurityScopedResource(),
                  let file = TorrentFile(with: url)
            else { return }

            guard let rootViewController = window?.rootViewController
            else { return }

            guard !TorrentService.shared.torrents.contains(where: { $0.infoHashes == file.infoHashes })
            else {
                let alert = UIAlertController(title: "This torrent already exists", message: "Torrent with hash:\n\"\(file.infoHashes.best.hex)\" already exists in download queue", preferredStyle: .alert)
                alert.addAction(.init(title: %"common.close", style: .cancel))
                rootViewController.present(alert, animated: true)
                return
            }

            rootViewController.topPresented.navigate(to: TorrentAddViewModel(with: .init(torrentFile: file)).resolveVC(), by: .present(wrapInNavigation: true))
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        startBackgroundIfNeeded()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        stopBackground()
    }

    override func binding() {
        bind(in: disposeBag) {
            tintColorBind
            appAppearanceBind
            backgroundDownloadModeBind
            backgroundStateObserverBind
#if canImport(ActivityKit)
            liveActivityBind
#endif
        }
    }
}