//
//  FirstViewController.swift
//  MyLocations
//
//  Created by Uy Cung Dinh on 10/16/19.
//  Copyright © 2019 Daylighter. All rights reserved.
//

import UIKit
import CoreLocation

class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getMyLocationButton: UIButton!
    
    private let locationManager = CLLocationManager()
    private var location: CLLocation?
    private var updatingLocation = false
    private var lastLocationError: Error?
    
    private let geocoder = CLGeocoder()
    private var placemark: CLPlacemark?
    private var performingReverseGeocoding = false
    private var lastGeocodingError: Error?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        getMyLocationButton.addTarget(self, action: #selector(getMyLocationButtonTapped), for: .touchUpInside)
        updateLabels()
    }
    
    @IBAction func getMyLocationButtonTapped(_ sender: UIButton) {
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        } else if authStatus == .restricted || authStatus == .denied {
            showLocationServicesDeniedAlert()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            placemark = nil
            lastGeocodingError = nil
            startLocationManager()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError: \(error.localizedDescription)")
        
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }
        lastLocationError = error
        stopLocationManager()
        updateLabels()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        print("didUpdateLocations \(newLocation)")
        // Sekip if the new location is over 5 seconds late
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
        }
        // Check if the coordinate is valid
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        
        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            location = newLocation
            lastLocationError = nil
            
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {
              print("*** We're done!")
              stopLocationManager()
            }
            updateLabels()
            
            if !performingReverseGeocoding {
                print("Geocoding")
                performingReverseGeocoding = true
                
                geocoder.reverseGeocodeLocation(newLocation, preferredLocale: nil, completionHandler: { [weak self] placemarks, error in
                    guard let self = self else { return }
                    self.lastGeocodingError = error
                    if error == nil, let p = placemarks, !p.isEmpty {
                      self.placemark = p.last!
                    } else {
                      self.placemark = nil
                    }
                    self.performingReverseGeocoding = false
                    self.updateLabels()
                })
            }
        }
    }

    private func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled", message: "Please enable location services for this app in Settings.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        present(alert, animated: true, completion: nil)
        alert.addAction(okAction)
    }
    
    private func updateLabels() {
        if let location = self.location {
            let addressText: String
            if let placemark = placemark {
              addressText = string(from: placemark)
            } else if performingReverseGeocoding {
              addressText = "Searching for Address..."
            } else if lastGeocodingError != nil {
              addressText = "Error Finding Address"
            } else {
              addressText = "No Address Found"
            }
            DispatchQueue.main.async {
                self.latitudeLabel.text = String(format: "%.8f", location.coordinate.latitude)
                self.longitudeLabel.text = String(format: "%.8f", location.coordinate.longitude)
                self.tagButton.isHidden = false
                self.messageLabel.text = ""
                self.addressLabel.text = addressText
            }
        } else {
            let statusMessage: String
            if let error = lastLocationError as NSError? {
                if error.domain == kCLErrorDomain && error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = "Tap 'Get My Location' to Start"
            }
            
            DispatchQueue.main.async {
                self.latitudeLabel.text = ""
                self.longitudeLabel.text = ""
                self.addressLabel.text = ""
                self.tagButton.isHidden = true
                self.messageLabel.text = statusMessage
            }
        }
        configureGetMyLocationButton()
    }
    
    private func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            updatingLocation = true
        }
    }
    
    private func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
        }
    }
    
    private func configureGetMyLocationButton() {
        if updatingLocation {
            getMyLocationButton.setTitle("Stop", for: .normal)
        } else {
            getMyLocationButton.setTitle("Get My Location", for: .normal)
        }
    }
    
    private func string(from placemark: CLPlacemark) -> String {
        var line1 = ""
        // house number
        if let s = placemark.subThoroughfare {
            line1 += s + " "
        }
        // street name
        if let s = placemark.thoroughfare {
            line1 += s
        }
        
        var line2 = ""
        // city
        if let s = placemark.locality {
            line2 += s + " "
            print("locality \(s)")
        }
        // state or province
        else if let s = placemark.administrativeArea {
            line2 += s + " "
            print("administrativeArea \(s)")
        }
        
        if let s = placemark.postalCode {
            line2 += s
        }
        
        return line1 + "\n" + line2
    }
}

