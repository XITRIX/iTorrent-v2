//
//  AppDelegate+Meta.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 25.04.2024.
//

import Foundation
import FBAudienceNetwork

extension AppDelegate {
    func registerMeta() {
        FBAudienceNetworkAds.initialize(with: nil, completionHandler: nil)
        FBAdSettings.setAdvertiserTrackingEnabled(true)
    }
}
