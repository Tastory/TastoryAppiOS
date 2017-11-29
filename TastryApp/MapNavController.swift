//
//  MapNavController.swift
//  PervasiveMapPrototype
//
//  Created by Howard Lee on 2017-11-04.
//  Copyright © 2017 Tastry. All rights reserved.
//


import AsyncDisplayKit

@objc protocol MapNavControllerDelegate {
  @objc optional func mapNavController(_ mapNavController: MapNavController, didSelect annotation: MKAnnotation)
  
  @objc optional func mapNavControllerWasMovedByUser(_ mapNavController: MapNavController)
}



class MapNavController: ASNavigationController {

  // MARK: - Struct & Enum Definition
  
  struct MapState {
    fileprivate var region: MKCoordinateRegion
    fileprivate var tracking: Bool
  }
  
  
  // MARK: - Constants
  
  struct Constants {
    static let DefaultCLCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(49.2781372),
                                                              longitude: CLLocationDegrees(-123.1187237))  // This is set to Vancouver
    static let DefaultMinMapWidth: CLLocationDistance = 800 // 800m
    static let DefaultMapWidth: CLLocationDistance = 2500 // 2.5km
    static let DefaultMaxMapWidth: CLLocationDistance = 8000  // 8km
    
    static let MapAnnotationMarginFraction: Double = 0.1
  }
  
  
  
  // MARK: - Private Instance Variables
  
  private var locationWatcher: LocationWatch.Context?
  private var exposedRectInset: UIEdgeInsets?
  private var exposedRect: CGRect?
  private var currentMapWidth: CLLocationDistance?
  
  
  // MARK: - Public Instance Variable
  
  var mapDelegate: MapNavControllerDelegate?
  var mapView: MKMapView!
  
  var currentMapState: MapState {
    return MapState(region: mapView.region, tracking: isTracking)
  }
  
  var exposedMapRect: MKMapRect {
    return exposedRegion.toMapRect()
  }
  
  var exposedRegion: MKCoordinateRegion {
    if let exposedRect = exposedRect {
      return mapView.convert(exposedRect, toRegionFrom: mapView)
    } else {
      return mapView.region
    }
  }
  
  var defaultCoordinate: CLLocationCoordinate2D { return Constants.DefaultCLCoordinate2D }
  var defaultMapWidth: CLLocationDistance { return Constants.DefaultMapWidth }
  var minMapWidth: CLLocationDistance { return Constants.DefaultMinMapWidth }
  var maxMapWidth: CLLocationDistance { return Constants.DefaultMaxMapWidth }
  
  var selectedAnnotation: MKAnnotation? {
    if mapView.selectedAnnotations.count <= 0 {
      return nil
    } else {
      return mapView.selectedAnnotations[0]
    }
  }
  
  var isTracking: Bool = false
  
  
  
  // MARK: - Public Instance Functions
  
  func boundedMapWidth() -> CLLocationDistance {
    // Base the span of the new mapView on what the mapView span currently is
    var mapWidth = exposedRegion.longitudinalMeters
    
    // Take the lesser of current or default max latitude degrees
    mapWidth = min(mapWidth, maxMapWidth)
    
    // Take the greater of current or default min latitude degrees
    return max(mapWidth, minMapWidth)
  }
  
  
  func setExposedRect(with exposedView: UIView) {
    guard let exposedSuperview = exposedView.superview else {
      CCLog.fatal("Exposed view has no superview")
    }

    self.exposedRect = exposedSuperview.convert(exposedView.frame, to: mapView)
    self.exposedRectInset = mapView.bounds.makeInsetBySubtracting(exposedRect!)
  }
  
  
  func showRegionExposed(_ region: MKCoordinateRegion, animated: Bool, turnOffTracking: Bool = true) {
    if turnOffTracking { stopTracking() }
    
    if let exposedRectInset = exposedRectInset {
      mapView.setVisibleMapRect(region.toMapRect(), edgePadding: exposedRectInset, animated: animated)
    } else {
      mapView.setRegion(region, animated: animated)
    }
  }
  

  func showMapRectExposed(_ mapRect: MKMapRect, animated: Bool, turnOffTracking: Bool = true) {
    if turnOffTracking { stopTracking() }
    
    if let exposedRectInset = exposedRectInset {
      mapView.setVisibleMapRect(mapRect, edgePadding: exposedRectInset, animated: animated)
    } else {
      mapView.setVisibleMapRect(mapRect, animated: animated)
    }
  }
  
  
  func showDefaultRegionExposed(animated: Bool) {
    let region = MKCoordinateRegionMakeWithDistance(Constants.DefaultCLCoordinate2D, defaultMapWidth, defaultMapWidth)
    showRegionExposed(region, animated: true)
  }
  
  
  func showCurrentRegionExposed(animated: Bool) {
    // Base the span of the new mapView on what the mapView span currently is
    if !isTracking {
      currentMapWidth = boundedMapWidth()
    }
    startTracking()
  }
  
  
  func selectCenteredInExposedRect(annotation: MKAnnotation, turnOffTracking: Bool = true) {
    if turnOffTracking { stopTracking() }
    
    let region = MKCoordinateRegionMakeWithDistance(annotation.coordinate, boundedMapWidth(), boundedMapWidth())
    showRegionExposed(region, animated: true)
    mapView.selectAnnotation(annotation, animated: true)
  }
  
  
  func showRegionExposed(containing annotations: [MKAnnotation], turnOffTracking: Bool = true) {
    if turnOffTracking { stopTracking() }
    
    let initialMapPoint = MKMapPointForCoordinate(annotations[0].coordinate)
    var mapMinX: Double = initialMapPoint.x
    var mapMaxX: Double = initialMapPoint.x
    var mapMinY: Double = initialMapPoint.y
    var mapMaxY: Double = initialMapPoint.y
    
    // Calculate of maximum extent of annotations
    for annotation in annotations {
      let annotationMapPoint = MKMapPointForCoordinate(annotation.coordinate)
      
      if annotationMapPoint.x < mapMinX {
        mapMinX = annotationMapPoint.x
      } else if annotationMapPoint.x > mapMaxX {
        mapMaxX = annotationMapPoint.x
      }
      
      if annotationMapPoint.y < mapMinY {
        mapMinY = annotationMapPoint.y
      } else if annotationMapPoint.y > mapMaxY {
        mapMaxY = annotationMapPoint.y
      }
    }
    
    // Adjust for margin
    let mapWidth = (mapMaxX - mapMinX) / (1 - 2*Constants.MapAnnotationMarginFraction)
    let mapHeight = (mapMaxY - mapMinY) / (1 - 2*Constants.MapAnnotationMarginFraction)
    mapMinX = mapMinX - mapWidth * Constants.MapAnnotationMarginFraction
    mapMaxX = mapMinX + mapWidth
    mapMinY = mapMinY - mapHeight * Constants.MapAnnotationMarginFraction
    mapMaxY = mapMinY + mapHeight
    let finalMapRect = MKMapRectMake(mapMinX, mapMinY, mapWidth, mapHeight)
    
    // Display Map
    showMapRectExposed(finalMapRect, animated: true)
  }
  
  
  func resumeMapState(_ mapState: MapState, animated: Bool) {
    mapView.setRegion(mapState.region, animated: animated)
    if mapState.tracking { startTracking() }
  }
  
  
  // Annotation Management
  
  func select(annotation: MKAnnotation, animated: Bool) {
    mapView.selectAnnotation(annotation, animated: animated)
  }
  
  func add(annotation: MKAnnotation) {
    mapView.addAnnotation(annotation)
  }
  
  func add(annotations: [MKAnnotation]) {
    mapView.addAnnotations(annotations)
  }
  
  func remove(annotation: MKAnnotation) {
    mapView.removeAnnotation(annotation)
  }
  
  func remove(annotations: [MKAnnotation]) {
    mapView.removeAnnotations(annotations)
  }
  
  func removeAllAnnotations() {
    mapView.removeAnnotations(mapView.annotations)
  }
  
  
  // Map Tracking Management
  
  func stopTracking() {
    CCLog.verbose("MapNav Stop Tracking")
    isTracking = false
    locationWatcher?.pause()
  }
  
  
  func startTracking() {
    CCLog.verbose("MapNav Start Tracking")
    isTracking = true
    locationWatcher?.resume()
  }
  
  
  
  // MARK: - Private Instance Functions
  @objc private func mapWasDragged(_ panRecognizer: UIGestureRecognizer) {
    if panRecognizer.state == .began {
      mapDelegate?.mapNavControllerWasMovedByUser?(self)
    }
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    LocationWatch.initializeGlobal()
    
    setNavigationBarHidden(true, animated: false)
    setToolbarHidden(true, animated: false)
    
    // Create Map and set Default Map Configurations
    mapView = MKMapView(frame: view.bounds)
    mapView.delegate = self
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.showsUserLocation = true
    mapView.setUserTrackingMode(.none, animated: false)
    
    view.addSubview(mapView)
    view.sendSubview(toBack: mapView)
    
    // Add a Pan Gesture Recognizer to the Map View to detect User initiated Map movement
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(mapWasDragged(_:)))
    panGestureRecognizer.delegate = self
    mapView.addGestureRecognizer(panGestureRecognizer)
    
    // Start/Restart the Location Watcher
    isTracking = true
    locationWatcher = LocationWatch.global.start() { (location, error) in
      if let error = error {
        CCLog.warning("LocationWatch returned error - \(error.localizedDescription)")
        return
      }
      
      if let location = location, self.isTracking {
        let region = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                        self.currentMapWidth ?? self.defaultMapWidth,
                                                        self.currentMapWidth ?? self.defaultMapWidth)
        DispatchQueue.main.async { self.showRegionExposed(region, animated: true, turnOffTracking: false) }
      }
    }
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if isTracking { locationWatcher?.resume() }
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    locationWatcher?.pause()
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    CCLog.warning("Received Memory Warning")
  }
  
  
  func topViewWillResignActive() {
    if let topViewController = topViewController as? OverlayViewController {
      topViewController.topViewWillResignActive()
    }
  }
  
  
  func topViewDidEnterBackground() {
    if let topViewController = topViewController as? OverlayViewController {
      topViewController.topViewDidEnterBackground()
    }
  }
  
  
  func topViewWillEnterForeground() {
    if let topViewController = topViewController as? OverlayViewController {
      topViewController.topViewWillEnterForeground()
    }
  }
  
  
  func topViewDidBecomeActive() {
    if let topViewController = topViewController as? OverlayViewController {
      topViewController.topViewDidBecomeActive()
    }
  }
}


extension MapNavController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    if let annotation = view.annotation {
      mapDelegate?.mapNavController?(self, didSelect: annotation)
    }
  }
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is MKUserLocation {
      return nil
    }
    else if #available(iOS 11.0, *) {
      let markerAnnotationView = MKMarkerAnnotationView()
      markerAnnotationView.titleVisibility = .visible
      markerAnnotationView.displayPriority = .required
      return markerAnnotationView
    } else {
      return nil
    }
  }
}


extension MapNavController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}
