//
//  MapViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-20.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation


class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate {

  // MARK: - Class Constants
  private struct MapLocationConstants {
    static let defaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let defaultMaxMapSpan = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(0.05),
                                                    longitudeDelta: CLLocationDegrees(0.05))
    static let defaultMinMapSpan = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(0.005),
                                                    longitudeDelta: CLLocationDegrees(0.005))
    
    static let defaultDistanceFilter = 30.0  // meters, for LocationManager

  }
  
  
  // MARK: - Class Variables
  private var locationManager = CLLocationManager()
  private var currentMapSpan: MKCoordinateSpan = MapLocationConstants.defaultMaxMapSpan
  

  // MARK: - IBOutlets
  @IBOutlet weak var mapView: MKMapView?
  @IBOutlet weak var panGestureRecognizer: UIPanGestureRecognizer?
  @IBOutlet weak var pinchGestureRecognizer: UIPinchGestureRecognizer?
  @IBOutlet weak var tapGestureRecognizer: UITapGestureRecognizer?
  @IBOutlet weak var locationField: UITextField?
  
  
  // MARK: - IBActions
  @IBAction func mapGestureDetected(_ recognizer: UIGestureRecognizer) {
    
    // Stop updating location if any gestures detected against Map
    switch recognizer.state {
    case .began, .ended:
      locationManager.stopUpdatingLocation()
    default:
      break
    }
  }
  
  
  @IBAction func currentLocationReturn(_ sender: UIButton) {
    
    // Restrict to a certain range of zoom when returning map to current location
    // See MKCoordinateSpan+Extensions
    if let mapView = mapView {
      currentMapSpan = min(mapView.region.span, MapLocationConstants.defaultMaxMapSpan)
      currentMapSpan = max(currentMapSpan, MapLocationConstants.defaultMinMapSpan)
    }

    // Start updating location again
    locationManager.startUpdatingLocation()
  }
  
  
  // MARK: - View Controller Life Cycles
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    mapView?.delegate = self
    panGestureRecognizer?.delegate = self
    pinchGestureRecognizer?.delegate = self
    tapGestureRecognizer?.delegate = self
    locationField?.delegate = self
    
    // Provide a default Map Region incase Location Update is slow or user denies authorization
    let region = MKCoordinateRegion(center: MapLocationConstants.defaultCLCoordinate2D,
                                    span: MapLocationConstants.defaultMinMapSpan)
    mapView?.setRegion(region, animated: false)
    
    // Setup Location Manager and Start Location Updates
    locationManager.delegate = self
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest //kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = MapLocationConstants.defaultDistanceFilter
    locationManager.activityType = CLActivityType.fitness  // Fitness Type includes Walking
    locationManager.allowsBackgroundLocationUpdates = false
    locationManager.pausesLocationUpdatesAutomatically = true
    locationManager.disallowDeferredLocationUpdates()
    locationManager.startUpdatingLocation()

  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
  /*
  // MARK: - Navigation

  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
  }
  */

  
  // MARK: - CLLocationManager Delegates
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    let region = MKCoordinateRegion(center: locations[0].coordinate, span: currentMapSpan)
    mapView?.setRegion(region, animated: true)
  }
  
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error.localizedDescription)  // TODO: Log this error to internal log with a certain verbose level
    
    guard let errorCode = error as? CLError else {
      assertionFailure("Not getting CLError upon a Location Manager Error")
      return
    }
    
    print("CLError Code = \(errorCode.code.rawValue)")
    switch errorCode.code {
    case .locationUnknown, .headingFailure:
      // Allow to just continue and hope for a better update later
      break
    case .denied:
      // User denied authorization
      manager.stopUpdatingLocation()
      // TODO: Do we need to do more here?
    default:
      // Allow to just continue and hope for a better update later
      break
    }
  }
  
  /*
  // MARK: - MKMapView Delegates
  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    print("Region Will Change Called")
  }
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    print("Region Did Change Called")
  }
 */
  
  // MARK: - UIGestureRecognizer Delegates
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  
  // MARK: - UITextField Delegates
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    
    if let location = textField.text, let region = mapView?.region {
      let geocoder = CLGeocoder()
      geocoder.geocodeAddressString(location, in: region.toCLRegion()) { (<#[CLPlacemark]?#>, <#Error?#>) in
        <#code#>
      }
      textField.text
    }
    textField.resignFirstResponder()
    return true
  }
}
