//
//  MKCoordinateRegion+Extension.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-11.
//  Copyright © 2017 Tastry. All rights reserved.
//

import MapKit

extension MKCoordinateRegion {
  
 func toMapRect() -> MKMapRect {
    let topLeft = CLLocationCoordinate2D(latitude: self.center.latitude + (self.span.latitudeDelta/2), longitude: self.center.longitude - (self.span.longitudeDelta/2))
    let bottomRight = CLLocationCoordinate2D(latitude: self.center.latitude - (self.span.latitudeDelta/2), longitude: self.center.longitude + (self.span.longitudeDelta/2))
    
    let a = MKMapPointForCoordinate(topLeft)
    let b = MKMapPointForCoordinate(bottomRight)
    
    return MKMapRect(origin: MKMapPoint(x:min(a.x,b.x), y:min(a.y,b.y)), size: MKMapSize(width: abs(a.x-b.x), height: abs(a.y-b.y)))
  }
}
