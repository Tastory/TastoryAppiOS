//
//  MapNavController.swift
//  PervasiveMapPrototype
//
//  Created by Howard Lee on 2017-11-04.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AsyncDisplayKit

class MapNavController: ASNavigationController {

  var mapView: MKMapView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setNavigationBarHidden(true, animated: false)
    setToolbarHidden(true, animated: false)
    
    mapView = MKMapView(frame: view.bounds)
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
