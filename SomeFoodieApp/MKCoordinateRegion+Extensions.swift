//
//  MKCoordinateRegion+Extensions.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-22.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import MapKit
import CoreLocation

// Extend the MKCoordinateSpan class so they are comparable
extension MKCoordinateRegion {
  
  public init(region: CLCircularRegion) {
    center = region.center
    span = MKCoordinateSpan(heightKm: region.radius/1000*2, widthKm: region.radius/1000*2)
  }

  func toCLRegion() -> CLCircularRegion {
    return CLCircularRegion(center: self.center, radius: self.span.greaterValue*1000/2, identifier: "currentMapRegion")
  }
}
