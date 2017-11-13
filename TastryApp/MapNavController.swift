//
//  MapNavController.swift
//  PervasiveMapPrototype
//
//  Created by Howard Lee on 2017-11-04.
//  Copyright © 2017 Tastry. All rights reserved.
//


import AsyncDisplayKit

class MapNavController: ASNavigationController {

  
  // MARK: - Public Instance Variable
  
  var mapView: MKMapView!

  
  
  // MARK: - Private Instance Functions
  
  private var exposedRectInset: UIEdgeInsets?
  private var exposedRect: CGRect?
  
  
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
