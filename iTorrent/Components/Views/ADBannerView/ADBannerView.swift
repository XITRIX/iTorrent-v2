//
//  ADBannerView.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 25.04.2024.
//

import FBAudienceNetwork
import UIKit

class ADBannerView: BaseView {
    @IBOutlet var adUIView: UIView!
    @IBOutlet var adIconImageView: FBMediaView!
    @IBOutlet var adChoicesView: FBAdChoicesView!
    @IBOutlet var adAdvertiserNameLabel: UILabel!
    @IBOutlet var adSponsoredLabel: UILabel!
    @IBOutlet var adCallToActionButton: UIButton!

    override func setup() {
        let nativeBannerAd = FBNativeBannerAd()
        nativeBannerAd.delegate = self
        nativeBannerAd.loadAd()
    }

    private var nativeBannerAd: FBNativeBannerAd?
}

extension ADBannerView: FBNativeBannerAdDelegate {
    func nativeBannerAdDidLoad(_ nativeBannerAd: FBNativeBannerAd) {
        if let previousAd = self.nativeBannerAd, previousAd.isAdValid {
            previousAd.unregisterView()
        }

        self.nativeBannerAd = nativeBannerAd

        adAdvertiserNameLabel.text = nativeBannerAd.advertiserName
        adSponsoredLabel.text = nativeBannerAd.sponsoredTranslation

        if let callToAction = nativeBannerAd.callToAction {
            adCallToActionButton.isHidden = false
            adCallToActionButton.setTitle(callToAction, for: .normal)
        } else {
            adCallToActionButton.isHidden = true
        }

        // Set native banner ad view tags to declare roles of your views for better analysis in future
        // We will be able to provide you statistics how often these views were clicked by users
        // Views provided by Facebook already have appropriate tag set
        adAdvertiserNameLabel.nativeAdViewTag = .title
        adCallToActionButton.nativeAdViewTag = .callToAction

        // Specify the clickable areas. View you were using to set ad view tags should be clickable.
        let clickableViews: [UIView] = [adCallToActionButton]
        nativeBannerAd.registerView(
            forInteraction: adUIView,
            iconView: adIconImageView,
            viewController: viewController,
            clickableViews: clickableViews
        )

        /*
         // If you don't want to provide native ad view tags you can simply
         // Wire up UIView with the native banner ad; the whole UIView will be clickable.
         nativeBannerAd.registerView(
         forInteraction: adUIView,
         iconView: adIconImageView,
         viewController: self
         )
         */

        adChoicesView.corner = .topLeft
        adChoicesView.nativeAd = nativeBannerAd
    }

    func nativeBannerAdDidClick(_ nativeBannerAd: FBNativeBannerAd) {
        print("Native banner ad was clicked.")
    }

    func nativeBannerAdDidFinishHandlingClick(_ nativeBannerAd: FBNativeBannerAd) {
        print("Native banner ad did finish click handling.")
    }

    func nativeBannerAdWillLogImpression(_ nativeBannerAd: FBNativeBannerAd) {
        print("Native banner ad impression is being captured.")
    }

    func nativeBannerAd(_ nativeBannerAd: FBNativeBannerAd, didFailWithError error: Error) {
        print("Native banner ad failed to load with error: \(error.localizedDescription)")
    }
}
