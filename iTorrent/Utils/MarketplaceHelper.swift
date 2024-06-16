//
//  MarketplaceHelper.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 16.06.2024.
//

import Foundation
#if canImport(MarketplaceKit)
import MarketplaceKit
#endif

final class MarketplaceHelper: @unchecked Sendable {
    static let shared = MarketplaceHelper()

    private(set) var currentDistributor: AppDistributor = .other

    init() {
        Task {
            if #available(iOS 17.4, *) {
                currentDistributor = .init(from: try await MarketplaceKit.AppDistributor.current)
            } else {
                currentDistributor = .other
            }
        }
    }

    var isForAppleDistribution: Bool {
//        switch currentDistributor {
//        case .appStore:
//            print("App Store")
//            return true
//        case .testFlight:
//            print("TestFlight")
//            return true
//        case .marketplace(let bundleId):
//            print("Alternative marketplace (\(bundleId))")
//            return true
//        case .web:
//            print("Website")
//            return false
//        case .other:
//            print("Other")
//            return false
//        }

#if IS_EU
        true
#else
        false
#endif
    }

    public enum AppDistributor {
        case appStore
        case testFlight
        case marketplace(String)
        case web
        case other

        @available(iOS 17.4, *)
        init(from appDistributor: MarketplaceKit.AppDistributor) {
            switch appDistributor {
            case .appStore:
                self = .appStore
            case .testFlight:
                self = .testFlight
            case .marketplace(let string):
                self = .marketplace(string)
            case .web:
                self = .web
            case .other:
                self = .other
            @unknown default:
                self = .other
            }
        }
    }
}
