//
//  LocationBackgroundService.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 05/04/2024.
//

import CoreLocation

class LocationBackgroundService: NSObject, @unchecked Sendable {
//#if IS_EU
    nonisolated(unsafe) static weak var shared: LocationBackgroundService?
    @Published var currentLocation: CLLocation?
    @Published var isAllowed: Bool = false
//#endif

    override init() {
        super.init()
        locationManager.delegate = self

#if IS_EU
        isAllowed = locationManager.authorizationStatus != .denied && locationManager.authorizationStatus != .restricted
        Self.shared = self
#endif
    }

    var isRunning: Bool = false

    private var continuation: CheckedContinuation<Void, Never>?
    private let locationManager = CLLocationManager()
}

extension LocationBackgroundService: BackgroundServiceProtocol {
    func start() -> Bool {
        guard !isRunning else { return true }

        isRunning = runLocationService()
        return isRunning
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        isRunning = false
    }

    func prepare() async -> Bool {
        var status = locationManager.authorizationStatus
        guard status == .notDetermined else {
            return status != .denied && status != .restricted
        }

        locationManager.requestAlwaysAuthorization()
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        status = locationManager.authorizationStatus
        return status != .restricted && status != .denied && status != .notDetermined
    }
}

private extension LocationBackgroundService {
    func runLocationService() -> Bool {
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced

        let status = locationManager.authorizationStatus
        guard status != .restricted && status != .denied
        else { return false }

#if !os(visionOS)
        locationManager.allowsBackgroundLocationUpdates = true
#endif
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.showsBackgroundLocationIndicator = PreferencesStorage.shared.isBackgroundLocationIndicatorEnabled
        locationManager.startUpdatingLocation()
        return true
    }
}

extension LocationBackgroundService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        isAllowed = manager.authorizationStatus != .denied && manager.authorizationStatus != .restricted

        guard manager.authorizationStatus != .notDetermined
        else { return }

        Task {
            continuation?.resume()
            continuation = nil
        }
    }

#if IS_EU
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
#endif
}
