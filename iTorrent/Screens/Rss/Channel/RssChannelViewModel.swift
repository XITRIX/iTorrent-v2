//
//  RssChannelViewModel.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 08.04.2024.
//

import Combine
import MvvmFoundation
import UIKit

class RssChannelViewModel: BaseCollectionViewModelWith<RssModel>, @unchecked Sendable {
    @Published var title: String = ""
    @Published var searchQuery: String = ""

    var model: RssModel!

    var items: [RssChannelItemCellViewModel] = []

    override func prepare(with model: RssModel) {
        self.model = model
        disposeBag.bind {
            model.displayTitle.sink { [unowned self] text in
                title = text
            }
            Publishers.combineLatest(model.$items, $searchQuery) { models, searchQuery in
                Self.filter(models: models, by: searchQuery)
            }.sink { [unowned self] models in
                Task { await reload(with: models) }
            }
        }

        Task { @MainActor in
            trailingSwipeActionsConfigurationProvider = { [unowned self] indexPath in
                let itemModel = items[indexPath.item].model

                guard let index = model.items.firstIndex(where: { $0 == itemModel })
                else { return nil }

                let readed = model.items[index].readed
                let action = UIContextualAction(style: .normal, title: readed ? %"rsschannel.unseen" : %"rsschannel.seen", handler: { [unowned self] _, _, completion in
                    setSeen(!readed, for: index)
                    completion(true)
                })
                //            action.image = readed ? .init(systemName: "eye.slash") : .init(systemName: "eye")
                action.backgroundColor = PreferencesStorage.shared.tintColor
                return .init(actions: [action])
            }
        }

        refreshTask = { [weak self] in
            do {
                try await model.update()
                self?.rssFeedProvider.saveState()
            }
            catch {}
        }
    }

    func readAll() {
        ignoreReloadRequests = true
        for index in 0 ..< model.items.count {
//            model.items[index].readed = true // Questionable, not sure it should be flaged as well
            model.items[index].new = false
        }
        rssFeedProvider.saveState()
        ignoreReloadRequests = false
        Task { await reload(with: model.items) }
    }

    func setSeen(_ seen: Bool, for itemModel: RssItemModel) {
        guard let index = model.items.firstIndex(where: { $0 == itemModel })
        else { return }

        model.items[index].readed = seen
        model.items[index].new = false
        rssFeedProvider.saveState()
    }

    private var ignoreReloadRequests: Bool = false
    @Injected private var rssFeedProvider: RssFeedProvider
}

private extension RssChannelViewModel {
    func reload(with models: [RssItemModel]) async {
        guard !ignoreReloadRequests else { return }

        // TODO: Need to rewrite this DispatchQueue mess
//        DispatchQueue.global(qos: .userInitiated).async { [self] in
            items = models.map { model in
                let vm: RssChannelItemCellViewModel
                if let existing = items.first(where: { $0.model == model }) {
                    vm = existing
                } else {
                    vm = RssChannelItemCellViewModel()
                }

                vm.prepare(with: .init(rssModel: model, selectAction: { [unowned self] in
                    setSeen(true, for: model)
                    navigate(to: RssDetailsViewModel.self, with: model, by: .detail(asRoot: true))
                }))

                return vm
            }.removingDuplicates()

//            DispatchQueue.main.async { [self] in
                sections = [.init(id: "rss", style: .plain, items: items)]
//            }
//        }
    }

    func setSeen(_ seen: Bool, for index: Int) {
        model.items[index].readed = seen
        model.items[index].new = false
        rssFeedProvider.saveState()
    }

    static func filter(models: [RssItemModel], by searchQuery: String) -> [RssItemModel] {
        models.filter { model in
            searchQuery.split(separator: " ").allSatisfy { (model.title ?? "").localizedCaseInsensitiveContains($0) } ||
                searchQuery.split(separator: " ").allSatisfy { (model.description ?? "").localizedCaseInsensitiveContains($0) }
        }
    }
}
