//
//  Location.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-08.
//

import Foundation
import CoreLocation

class Location: NSObject, CLLocationManagerDelegate {
    var manager: CLLocationManager = CLLocationManager()
    
    func start() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info("location: did change")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("location: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            logger.info("location: \(location)")
        }
    }
}
