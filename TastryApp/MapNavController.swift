//
//  MapNavController.swift
//  PervasiveMapPrototype
//
//  Created by Howard Lee on 2017-11-04.
//  Copyright © 2017 Tastry. All rights reserved.
//


import AsyncDisplayKit

class MapNavController: ASNavigationController {

  // MARK: - Constants
  
  struct Constants {
    static let MapAnnotationMarginFraction: Double = 0.05
    static let DefaultMapDelta: CLLocationDegrees = 0.05
  }
  
  
  
  // MARK: - Private Instance Functions
  
  private var exposedRectInset: UIEdgeInsets?
  private var exposedRect: CGRect?
  
  
  
  // MARK: - Public Instance Variable
  
  var mapView: MKMapView!
  
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
  
  
  
  // MARK: - Public Instance Functions
  
  func setExposedRect(with exposedView: UIView) {
    guard let exposedSuperview = exposedView.superview else {
      CCLog.fatal("Exposed view has no superview")
    }

    self.exposedRect = exposedSuperview.convert(exposedView.frame, to: mapView)
    self.exposedRectInset = mapView.bounds.makeInsetBySubtracting(exposedRect!)
  }
  
  
  func setRegionExposed(_ region: MKCoordinateRegion, animated: Bool) {
    if let exposedRectInset = exposedRectInset {
      mapView.setVisibleMapRect(region.toMapRect(), edgePadding: exposedRectInset, animated: animated)
    } else {
      mapView.setRegion(region, animated: animated)
    }
  }
  

  func setMapRectExposed(_ mapRect: MKMapRect, animated: Bool) {
    if let exposedRectInset = exposedRectInset {
      mapView.setVisibleMapRect(mapRect, edgePadding: exposedRectInset, animated: animated)
    } else {
      mapView.setVisibleMapRect(mapRect, animated: animated)
    }
  }
  
  
  func selectInExposedRect(annotation: MKAnnotation) {
    let annotationMapPoint = MKMapPointForCoordinate(annotation.coordinate)
    let currentMapRect = exposedMapRect
    
    if MKMapRectContainsPoint(currentMapRect, annotationMapPoint) {
      mapView.selectAnnotation(annotation, animated: true)
      return
    }
    
    var newOrigin = currentMapRect.origin
    let mapSize = currentMapRect.size
    let marginWidth = mapSize.width * Constants.MapAnnotationMarginFraction
    let marginHeight = mapSize.height * Constants.MapAnnotationMarginFraction
    
    if annotationMapPoint.x < MKMapRectGetMinX(currentMapRect) {
      let offset = annotationMapPoint.x - marginWidth - MKMapRectGetMinX(currentMapRect)
      newOrigin.x = currentMapRect.origin.x + offset
      
    } else if annotationMapPoint.x > MKMapRectGetMaxX(currentMapRect) {
      let offset = annotationMapPoint.x + marginWidth - MKMapRectGetMaxX(currentMapRect)
      newOrigin.x = currentMapRect.origin.x + offset
    }
    
    if annotationMapPoint.y < MKMapRectGetMinY(currentMapRect) {
      let offset = annotationMapPoint.y - marginHeight - MKMapRectGetMinY(currentMapRect)
      newOrigin.y = currentMapRect.origin.y + offset
      
    } else if annotationMapPoint.y > MKMapRectGetMaxY(currentMapRect) {
      let offset = annotationMapPoint.y + marginHeight - MKMapRectGetMaxY(currentMapRect)
      newOrigin.y = currentMapRect.origin.y + offset
    }
    
    setMapRectExposed(MKMapRect(origin: newOrigin, size: mapSize), animated: true)
    mapView.selectAnnotation(annotation, animated: true)
  }
  
  
  func selectCenteredInExposedRect(annotation: MKAnnotation) {
    let coordinate = annotation.coordinate
    let mapSpan = MKCoordinateSpan(latitudeDelta: Constants.DefaultMapDelta, longitudeDelta: Constants.DefaultMapDelta)
    setRegionExposed(MKCoordinateRegionMake(coordinate, mapSpan), animated: true)
    mapView.selectAnnotation(annotation, animated: true)
  }
  
  
  func showRegionExposed(containing annotations: [MKAnnotation]) {
    
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
    setMapRectExposed(finalMapRect, animated: true)
  }
  
  
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setNavigationBarHidden(true, animated: false)
    setToolbarHidden(true, animated: false)
    
    // Create Map and set Default Map Configurations
    mapView = MKMapView(frame: view.bounds)
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.showsUserLocation = true
    mapView.setUserTrackingMode(.follow, animated: true)
    
    view.addSubview(mapView)
    view.sendSubview(toBack: mapView)
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
