//
//  MKCoordinateRegion+Extension.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-11.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import MapKit

extension MKCoordinateRegion {

  var latitudinalMeters: CLLocationDistance {   // North South
    let mapRect = self.toMapRect()
    let mapMidX = MKMapRectGetMidX(mapRect)
    let mapMinY = MKMapRectGetMinY(mapRect)
    let mapMaxY = MKMapRectGetMaxY(mapRect)
    let mapMinPoint = MKMapPoint(x: mapMidX, y: mapMinY)
    let mapMaxPoint = MKMapPoint(x: mapMidX, y: mapMaxY)
    return MKMetersBetweenMapPoints(mapMinPoint, mapMaxPoint)
  }
  
  var longitudinalMeters: CLLocationDistance {  // East West
    let mapRect = self.toMapRect()
    let mapMidY = MKMapRectGetMidY(mapRect)
    let mapMinX = MKMapRectGetMinX(mapRect)
    let mapMaxX = MKMapRectGetMaxX(mapRect)
    let mapMinPoint = MKMapPoint(x: mapMinX, y: mapMidY)
    let mapMaxPoint = MKMapPoint(x: mapMaxX, y: mapMidY)
    return MKMetersBetweenMapPoints(mapMinPoint, mapMaxPoint)
  }
  
  func toMapRect() -> MKMapRect {
    let topLeft = CLLocationCoordinate2D(latitude: self.center.latitude + (self.span.latitudeDelta/2), longitude: self.center.longitude - (self.span.longitudeDelta/2))
    let bottomRight = CLLocationCoordinate2D(latitude: self.center.latitude - (self.span.latitudeDelta/2), longitude: self.center.longitude + (self.span.longitudeDelta/2))
    
    let a = MKMapPointForCoordinate(topLeft)
    let b = MKMapPointForCoordinate(bottomRight)
    
    return MKMapRect(origin: MKMapPoint(x:min(a.x,b.x), y:min(a.y,b.y)), size: MKMapSize(width: abs(a.x-b.x), height: abs(a.y-b.y)))
  }
}
