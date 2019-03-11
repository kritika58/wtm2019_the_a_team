//
//  NavigationViewController.swift
//  TheATeam
//
//  Created by Saransh Mittal on 10/03/19.
//  Copyright © 2019 Saransh Mittal. All rights reserved.
//

import UIKit
import GoogleMaps
import GooglePlaces
import Alamofire
import SwiftyJSON
import FirebaseDatabase
import Firebase

enum Location {
    case startLocation
    case destinationLocation
}

class NavigationViewController: UIViewController, GMSMapViewDelegate {
    
    @IBOutlet weak var startLocation: UITextField!
    @IBOutlet weak var destinationLocation: UITextField!
    var ref: DatabaseReference!
    
    var locationStart = CLLocation()
    var locationEnd = CLLocation()
    
    private let locationManager = CLLocationManager()
    var locationSelected = Location.startLocation
    
    @IBOutlet weak var mapsView: GMSMapView!
    
    func createMarker(titleMarker: String, iconMarker: UIImage, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2DMake(latitude, longitude)
        marker.title = titleMarker
        marker.icon = iconMarker
        marker.map = mapsView
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error to get location : \(error)")
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        
        ref.child("route").observe(.childChanged, with: {(snap: DataSnapshot) in
            self.ref.child("route").observeSingleEvent(of: .value, with: { (snapshot) in
                let temp = snapshot.value as! NSDictionary
                print(temp)
                
                let startLoc: CLLocation = CLLocation(latitude: CLLocationDegrees(temp["startLatitude"] as! NSNumber), longitude: CLLocationDegrees(temp["startLongitude"] as! NSNumber))
                
                let endLoc: CLLocation = CLLocation(latitude: CLLocationDegrees(temp["endLatitude"] as! NSNumber), longitude: CLLocationDegrees(temp["endLongitude"] as! NSNumber))
                
                if(self.distanceBetweenTwoLocations(source: self.locationStart, destination: startLoc) < 10) {
                    self.drawPath(startLocation: startLoc, endLocation: self.locationStart, color: UIColor.white)
                }
                if(self.distanceBetweenTwoLocations(source: self.locationEnd, destination: startLoc) < 1000) {
                    self.drawPath(startLocation: endLoc, endLocation: self.locationEnd, color: UIColor.white)
                }
            })
        })
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingHeading()
        
        let camera = GMSCameraPosition.camera(withLatitude: -7.9293122, longitude: 112.5879156, zoom: 15.0)
        
        self.mapsView.camera = camera
        self.mapsView.delegate = self
        self.mapsView?.isMyLocationEnabled = true
        self.mapsView.settings.myLocationButton = true
        self.mapsView.settings.compassButton = true
        self.mapsView.settings.zoomGestures = true
        
        do {
            if let styleURL = Bundle.main.url(forResource: "style", withExtension: "json") {
                mapsView.mapStyle = try GMSMapStyle(contentsOfFileURL: styleURL)
            } else {
                NSLog("Unable to find style.json")
            }
        } catch {
            NSLog("One or more of the map styles failed to load. \(error)")
        }

    }
    
    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        mapsView.isMyLocationEnabled = true
    }
    
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        mapsView.isMyLocationEnabled = true
        
        if (gesture) {
            mapView.selectedMarker = nil
        }
    }
    
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        mapsView.isMyLocationEnabled = true
        return false
    }
    
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        print("COORDINATE \(coordinate)") // when you tapped coordinate
    }
    
    func didTapMyLocationButton(for mapView: GMSMapView) -> Bool {
        mapsView.isMyLocationEnabled = true
        mapsView.selectedMarker = nil
        return false
    }
    
    func drawPath(startLocation: CLLocation, endLocation: CLLocation, color: UIColor) {
        let origin = "\(startLocation.coordinate.latitude),\(startLocation.coordinate.longitude)"
        let destination = "\(endLocation.coordinate.latitude),\(endLocation.coordinate.longitude)"
        let url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&mode=driving&key=AIzaSyCpKQ90KP3ZEJCaQeTQoviCLCB-ecMMnC0"
        Alamofire.request(url).responseJSON { response in
//            print(response.request as Any)  // original URL request
//            print(response.response as Any) // HTTP URL response
//            print(response.data as Any)     // server data
//            print(response.result as Any)   // result of response serialization
            
            let a = response.result
            let json = a.value as! NSDictionary
            let routes = json["routes"] as! [NSDictionary]
            // print route using Polyline
            for route in routes {
                let routeOverviewPolyline = route["overview_polyline"] as! NSDictionary
                let points = routeOverviewPolyline["points"] as! String
                let path = GMSPath.init(fromEncodedPath: points)
                let polyline = GMSPolyline.init(path: path)
                polyline.strokeWidth = 4
                polyline.strokeColor = color
                polyline.map = self.mapsView
            }
            
        }
    }
    
    func distanceBetweenTwoLocations(source:CLLocation,destination:CLLocation) -> Double{
        var distanceMeters = source.distance(from: destination)
        var distanceKM = distanceMeters / 1000
        let roundedTwoDigit = distanceKM.rounded()
        return roundedTwoDigit
    }
    
    // MARK: when start location tap, this will open the search location
    @IBAction func openStartLocation(_ sender: UIButton) {
        let autoCompleteController = GMSAutocompleteViewController()
        autoCompleteController.delegate = self
        // selected location
        locationSelected = .startLocation
        // Change text color
        UISearchBar.appearance().setTextColor(color: UIColor.black)
        self.locationManager.stopUpdatingLocation()
        self.present(autoCompleteController, animated: true, completion: nil)
    }
    
    // MARK: when destination location tap, this will open the search location
    @IBAction func openDestinationLocation(_ sender: UIButton) {
        let autoCompleteController = GMSAutocompleteViewController()
        autoCompleteController.delegate = self
        // selected location
        locationSelected = .destinationLocation
        // Change text color
        UISearchBar.appearance().setTextColor(color: UIColor.black)
        self.locationManager.stopUpdatingLocation()
        self.present(autoCompleteController, animated: true, completion: nil)
    }
    
    
    // MARK: SHOW DIRECTION WITH BUTTON
    @IBAction func showDirection(_ sender: UIButton) {
        // when button direction tapped, must call drawpath func
        self.drawPath(startLocation: locationStart, endLocation: locationEnd,color:  UIColor.yellow)
        Auth.auth().signInAnonymously() { (authResult, error) in
            self.ref.child("route").setValue(["startLatitude": self.locationStart.coordinate.latitude, "startLongitude": self.locationStart.coordinate.longitude,"endLatitude": self.locationEnd.coordinate.latitude, "endLongitude": self.locationEnd.coordinate.longitude])
        }
    }
}

extension NavigationViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        mapsView.animate(toBearing: newHeading.trueHeading)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard status == .authorizedWhenInUse else {
            return
        }
        locationManager.startUpdatingLocation()
        mapsView.isMyLocationEnabled = true
        mapsView.settings.myLocationButton = true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            return
        }
        mapsView.camera = GMSCameraPosition(target: location.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
        locationManager.stopUpdatingLocation()
    }
}

// MARK: - GMS Auto Complete Delegate, for autocomplete search location
extension NavigationViewController: GMSAutocompleteViewControllerDelegate {
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        print("Error \(error)")
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        // Change map location
        let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 16.0)
        // set coordinate to text
        if locationSelected == .startLocation {
            startLocation.text = "\(place.coordinate.latitude), \(place.coordinate.longitude)"
            locationStart = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            createMarker(titleMarker: "Location Start", iconMarker: UIImage.init(named: "mapspin")!, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        } else {
            destinationLocation.text = "\(place.coordinate.latitude), \(place.coordinate.longitude)"
            locationEnd = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            createMarker(titleMarker: "Location End", iconMarker: UIImage.init(named: "mapspin")!, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        }
        
        self.mapsView.camera = camera
        self.dismiss(animated: true, completion: nil)
        
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController,
                        didSelect prediction: GMSAutocompletePrediction) -> Bool {
        print("Primary: \(prediction.attributedPrimaryText)")
        print("Secondary: \(prediction.attributedSecondaryText)")
        return true;
    }
    
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
}

public extension UISearchBar {
    
    public func setTextColor(color: UIColor) {
        let svs = subviews.flatMap { $0.subviews }
        guard let tf = (svs.filter { $0 is UITextField }).first as? UITextField else { return }
        tf.textColor = color
    }
    
}
